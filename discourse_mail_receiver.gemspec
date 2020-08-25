# frozen-string-literal: true

# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'discourse_mail_receiver'
  spec.version       = '4.0.6'
  spec.authors       = ['Discourse Team']
  spec.email         = ['team@discourse.org']
  spec.description   = %q{A gem used to package the core .rb files of the mail-receiver.}
  spec.summary       = spec.description
  spec.homepage      = 'https://github.com/discourse/mail-receiver'
  spec.license       = 'MIT'

  spec.files         = Dir['lib/**/*.rb']
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'mail', '~> 2.7.1'
  spec.add_development_dependency 'mail', '~> 2.7.1'
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.required_ruby_version = '>=2.4.0'
end
