Gem::Specification.new do |spec|
  spec.name = "globiguard"
  spec.version = "0.1.0"
  spec.authors = ["GlobiGuard"]
  spec.summary = "Official dependency-minimal Ruby SDK for GlobiGuard."
  spec.description = "Dependency-minimal Ruby SDK for GlobiGuard trusted access workflows."
  spec.homepage = "https://globiguard.com"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.1"
  spec.metadata = {
    "homepage_uri" => "https://globiguard.com",
    "source_code_uri" => "https://github.com/globiguard/globiguard-ruby",
    "bug_tracker_uri" => "https://github.com/globiguard/globiguard-ruby/issues"
  }
  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE", "CHANGELOG.md", "CONTRIBUTING.md", "SECURITY.md"]
  spec.require_paths = ["lib"]
end

