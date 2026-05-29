# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "openssl"
require "time"
require "uri"

module GlobiGuard
  VERSION = "0.1.0"
  ENVIRONMENTS = %w[local sandbox live].freeze

  Credential = Struct.new(:kind, :project_id, :token, :environment, keyword_init: true) do
    def self.secret(project_id, token, environment)
      new(kind: "secret", project_id: project_id, token: token, environment: environment)
    end

    def self.publishable(project_id, token, environment)
      new(kind: "publishable", project_id: project_id, token: token, environment: environment)
    end

    def self.local(token = nil)
      new(kind: "local", project_id: nil, token: token, environment: "local")
    end
  end

  class Client
    attr_reader :transport

    def self.server(environment:, services:, credential:)
      raise ArgumentError, "Server clients require secret or local credentials." if credential.kind == "publishable"
      new(environment: environment, services: services, credential: credential)
    end

    def self.browser(environment:, services:, credential:)
      raise ArgumentError, "Browser clients cannot use secret credentials." if credential.kind == "secret"
      new(environment: environment, services: services, credential: credential)
    end

    def initialize(environment:, services:, credential:)
      @transport = Transport.new(environment: environment, services: services, credential: credential)
    end

    def actions = ResourceClient.new(@transport, "/v1/actions")
    def audit = ResourceClient.new(@transport, "/v1/audit")
    def installs = ResourceClient.new(@transport, "/v1/installs")
    def orgs = ResourceClient.new(@transport, "/v1/orgs")
    def policies = ResourceClient.new(@transport, "/v1/policies")
    def queue = ResourceClient.new(@transport, "/v1/queue")
    def workflows = ResourceClient.new(@transport, "/v1/workflows")
    def governed_actions = GovernedActions.new(@transport)
  end

  class Transport
    RESERVED_HEADERS = %w[
      x-globiguard-project-id
      x-globiguard-secret-key
      x-globiguard-publishable-key
      x-globiguard-local-mode
      x-globiguard-local-token
      x-globiguard-client
      x-globiguard-environment
    ].freeze

    def initialize(environment:, services:, credential:)
      raise ArgumentError, "Environment must be local, sandbox, or live." unless ENVIRONMENTS.include?(environment)
      raise ArgumentError, "Credential environment must match client environment." unless credential.environment == environment

      @environment = environment
      @services = services
      @credential = credential
      @base_uri = URI(services.fetch("controlPlane"))
      raise ArgumentError, "HTTPS is required outside local." if environment != "local" && @base_uri.scheme != "https"
      if credential.kind == "local" && !%w[localhost 127.0.0.1 ::1].include?(@base_uri.host)
        raise ArgumentError, "Local credentials require localhost or loopback URLs."
      end
    end

    def request(method, path, body: nil, headers: {})
      self.class.validate_path(path)
      headers.each_key do |name|
        raise ArgumentError, "Reserved GlobiGuard header cannot be overridden: #{name}" if RESERVED_HEADERS.include?(name.downcase)
      end

      uri = URI(@base_uri.to_s.sub(%r{/+\z}, "") + path)
      request = Net::HTTP.const_get(method.capitalize).new(uri)
      auth_headers.merge(headers).each { |name, value| request[name] = value }
      request["content-type"] = "application/json" if body
      request.body = JSON.generate(body) if body
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", read_timeout: 30, open_timeout: 30) do |http|
        http.request(request)
      end
      raise "GlobiGuard request failed with #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      response.body.nil? || response.body.empty? ? {} : JSON.parse(response.body)
    end

    def auth_headers
      headers = {
        "x-globiguard-client" => "globiguard-ruby/#{VERSION}",
        "x-globiguard-environment" => @environment
      }
      if @credential.kind == "local"
        headers["x-globiguard-local-mode"] = "true"
        headers["x-globiguard-local-token"] = @credential.token if @credential.token && !@credential.token.empty?
      else
        headers["x-globiguard-project-id"] = require_value(@credential.project_id, "project id")
        headers[@credential.kind == "secret" ? "x-globiguard-secret-key" : "x-globiguard-publishable-key"] = require_value(@credential.token, "credential token")
      end
      headers
    end

    def self.validate_path(path)
      raise ArgumentError, "Request path must start with /." unless path.start_with?("/")
      if path.start_with?("//") || path.include?("\\") || path.include?("?") || path.include?("#") || path.match?(/%(?![0-9A-Fa-f]{2})/)
        raise ArgumentError, "Unsafe request path."
      end
      raise ArgumentError, "Absolute request paths are not allowed." if URI(path).absolute?
      raise ArgumentError, "Dot segments are not allowed." if path.split("/").any? { |segment| segment == "." || segment == ".." }
    end

    private

    def require_value(value, label)
      raise ArgumentError, "Missing #{label}." if value.nil? || value.empty?
      value
    end
  end

  class ResourceClient
    def initialize(transport, base_path)
      @transport = transport
      @base_path = base_path
    end

    def list = @transport.request("get", @base_path)
    def get(id) = @transport.request("get", "#{@base_path}/#{URI.encode_www_form_component(id)}")
    def create(body) = @transport.request("post", @base_path, body: body)
    def post(suffix, body) = @transport.request("post", "#{@base_path}/#{URI.encode_www_form_component(suffix.sub(%r{\A/+}, ""))}", body: body)
  end

  class GovernedActions
    def initialize(transport)
      @transport = transport
    end

    def authorize_action_or_throw(body, idempotency_key: nil, correlation_id: nil)
      headers = {}
      headers["Idempotency-Key"] = idempotency_key if idempotency_key
      headers["x-correlation-id"] = correlation_id if correlation_id
      result = @transport.request("post", "/v1/actions/authorize", body: body, headers: headers)
      raise "GlobiGuard blocked the governed action." if result["decision"] == "BLOCK"
      result
    end
  end

  module TrustWebhook
    module_function

    def verify(headers, raw_body, signing_secret, tolerance_seconds: 300)
      normalized = headers.transform_keys { |key| key.to_s.downcase }
      delivery = normalized["x-globiguard-delivery-id"]
      timestamp = normalized["x-globiguard-timestamp"]
      event_type = normalized["x-globiguard-event-type"]
      signature = normalized["x-globiguard-signature"]
      return { ok: false, error: "Missing required webhook headers." } unless delivery && timestamp && event_type && signature
      return { ok: false, error: "Webhook timestamp is outside the replay window." } if (Time.now.to_i - timestamp.to_i).abs > tolerance_seconds

      signed = "globiguard-hmac-sha256-v1.#{delivery}.#{timestamp}.#{event_type}.#{raw_body}"
      expected = "v1=#{OpenSSL::HMAC.hexdigest("SHA256", signing_secret, signed)}"
      return { ok: false, error: "Invalid webhook signature." } unless secure_compare(expected, signature)

      { ok: true, envelope: JSON.parse(raw_body) }
    end

    def secure_compare(left, right)
      return false unless left.bytesize == right.bytesize
      left.bytes.zip(right.bytes).reduce(0) { |memo, pair| memo | (pair[0] ^ pair[1]) }.zero?
    end
  end

  module Bootstrap
    module_function

    def install_registration(profile, package_name:, package_version:, integration_kind:, runtime_kind:)
      validate_profile(profile)
      {
        environment: profile.fetch(:environment),
        deploymentMode: profile.fetch(:deploymentMode),
        issuerMode: profile.fetch(:issuerMode),
        installReporting: profile.fetch(:installReporting),
        installLabel: profile[:installLabel],
        package: { name: package_name, version: package_version },
        integration: { kind: integration_kind, runtime: runtime_kind }
      }
    end

    def validate_profile(profile)
      raise ArgumentError, "Invalid environment." unless ENVIRONMENTS.include?(profile[:environment])
      if profile[:deploymentMode] == "hosted" && profile[:issuerMode] != "globiguard_issued"
        raise ArgumentError, "Hosted deployments require globiguard_issued issuer mode."
      end
      return unless %w[self_hosted sovereign].include?(profile[:deploymentMode])

      raise ArgumentError, "Self-hosted and sovereign deployments require customer_issued issuer mode." unless profile[:issuerMode] == "customer_issued"
      raise ArgumentError, "Self-hosted and sovereign install reporting must be opt_in or disabled." unless %w[opt_in disabled].include?(profile[:installReporting])
    end
  end

  module Entitlements
    module_function

    def verify_signed_manifest(compact_jws, public_keys_by_id:)
      parts = compact_jws.split(".")
      raise ArgumentError, "Entitlement manifest must be compact JWS." unless parts.length == 3
      header = JSON.parse(base64url_decode(parts[0]))
      raise ArgumentError, "Entitlement manifest must use EdDSA." unless header["alg"] == "EdDSA"
      public_key = public_keys_by_id.fetch(header.fetch("kid"))
      signing_input = "#{parts[0]}.#{parts[1]}"
      signature = base64url_decode(parts[2])
      verify_ed25519!(base64url_decode(public_key), signing_input, signature)
      payload = JSON.parse(base64url_decode(parts[1]))
      raise ArgumentError, "Unsupported entitlement manifest schema." unless payload["schema"] == "globiguard.entitlement_manifest.v1"
      now = Time.now.to_i
      raise ArgumentError, "Entitlement manifest is not active yet." if payload["nbf"] && payload["nbf"].to_i > now
      raise ArgumentError, "Entitlement manifest is expired." if payload["exp"] && payload["exp"].to_i <= now
      payload
    end

    def verify_ed25519!(raw_public_key, signing_input, signature)
      prefix = [48, 42, 48, 5, 6, 3, 43, 101, 112, 3, 33, 0].pack("C*")
      key = OpenSSL::PKey.read(prefix + raw_public_key)
      verified = key.verify(nil, signature, signing_input)
      raise OpenSSL::PKey::PKeyError, "Invalid entitlement manifest signature." unless verified
    rescue NoMethodError, OpenSSL::PKey::PKeyError => e
      raise OpenSSL::PKey::PKeyError, "Ruby/OpenSSL Ed25519 verification is unavailable or failed: #{e.message}"
    end

    def base64url_decode(value)
      Base64.urlsafe_decode64(value + ("=" * ((4 - value.length % 4) % 4)))
    end
  end
end

