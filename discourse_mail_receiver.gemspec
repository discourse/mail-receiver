# frozen-string-literal: true

# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) if !$LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name = "discourse_mail_receiver"
  spec.version = "4.1.0"
  spec.authors = ["Discourse Team"]
  spec.email = ["team@discourse.org"]
  spec.description = "A gem used to package the core .rb files of the mail-receiver."
  spec.summary = spec.description
  spec.homepage = "https://github.com/discourse/mail-receiver"
  spec.license = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.0.0")

  spec.files = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "mail", "~> 2.7.1"
  spec.add_runtime_dependency "net-smtp", "~> 0.3.3"

  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop-discourse"
  spec.add_development_dependency "syntax_tree"
  spec.add_development_dependency "syntax_tree-disable_ternary"
end
