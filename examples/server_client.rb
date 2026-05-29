# frozen_string_literal: true

require_relative "../lib/globiguard"

client = GlobiGuard::Client.server(
  environment: "sandbox",
  services: { "controlPlane" => "https://api.globiguard.com" },
  credential: GlobiGuard::Credential.secret("proj_example", "ggsk_example_replace_me", "sandbox")
)

decision = client.governed_actions.authorize_action_or_throw(
  actionType: "refund",
  actor: { id: "user_123" },
  target: { id: "order_456" },
  reason: "Customer support refund approval"
)

puts decision

