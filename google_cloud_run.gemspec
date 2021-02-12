require_relative "lib/google_cloud_run/version"

Gem::Specification.new do |spec|
  spec.name        = "google_cloud_run"
  spec.version     = GoogleCloudRun::VERSION
  spec.authors     = ["Matt Kadenbach"]
  spec.homepage    = "https://github.com/mattes/google_cloud_run"
  spec.summary     = "Rails on Google Cloud Run"
  spec.description = "Opinionated Logging, Error Reporting and minor patches for Rails on Google Cloud Run."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files        = Dir["LICENSE", "README.md", "lib/**/*", "app/**/*", "config/**/*"]

  spec.add_dependency "rails", "~> 6.0"
  spec.add_dependency "google-cloud-tasks", "~> 2.1"
  spec.add_dependency "googleauth", "~> 0.15"
end
