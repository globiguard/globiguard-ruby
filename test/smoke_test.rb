# frozen_string_literal: true

require_relative "../lib/globiguard"

GlobiGuard::Transport.validate_path("/v1/actions")
expect_raises { GlobiGuard::Transport.validate_path("https://evil.example/v1") }
expect_raises { GlobiGuard::Transport.validate_path("/v1/../secret") }

registration = GlobiGuard::Bootstrap.install_registration(
  {
    environment: "sandbox",
    deploymentMode: "self_hosted",
    issuerMode: "customer_issued",
    installReporting: "opt_in"
  },
  package_name: "globiguard",
  package_version: "0.1.0",
  integration_kind: "sdk",
  runtime_kind: "ruby"
)
raise "bootstrap environment" unless registration[:environment] == "sandbox"

raw_body = '{"type":"globiguard.test"}'
timestamp = Time.now.to_i.to_s
delivery = "del_test"
secret = "whsec_test"
signed = "globiguard-hmac-sha256-v1.#{delivery}.#{timestamp}.globiguard.test.#{raw_body}"
signature = "v1=#{OpenSSL::HMAC.hexdigest("SHA256", secret, signed)}"
result = GlobiGuard::TrustWebhook.verify(
  {
    "x-globiguard-delivery-id" => delivery,
    "x-globiguard-timestamp" => timestamp,
    "x-globiguard-event-type" => "globiguard.test",
    "x-globiguard-signature" => signature
  },
  raw_body,
  secret
)
raise "webhook verification" unless result[:ok]

puts "GlobiGuard Ruby SDK smoke tests passed."

def expect_raises
  yield
  raise "Expected exception."
rescue StandardError
  nil
end

