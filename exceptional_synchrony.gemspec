require File.expand_path('../lib/exceptional_synchrony/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name        = 'exceptional_synchrony'
  spec.date        = '2014-01-16'
  spec.summary     = 'Extensions to EventMachine/Synchrony to work well with exceptions'
  spec.description = %q{}
  spec.authors     = ['Invoca']
  spec.email       = 'development@invoca.com'
  spec.homepage    = 'https://github.com/Invoca/exceptional_synchrony'
  spec.license     = 'MIT'
  spec.files       = `git ls-files`.split($/)
  spec.version     = ExceptionalSynchrony::VERSION
  spec.metadata    = {
      "source_code_uri"   => "https://github.com/Invoca/exceptional_synchrony",
      "allowed_push_host" => "https://rubygems.org"
  }

  spec.add_dependency 'em-synchrony'
  spec.add_dependency 'em-http-request'
  spec.add_dependency 'eventmachine'
  spec.add_dependency 'exception_handling', '~> 2.2'
  spec.add_dependency 'invoca-utils', '~> 0.3'
  spec.add_dependency 'concurrent-ruby', '~> 1.1'
  spec.add_dependency 'ulid', '~> 1.2'
  spec.add_dependency 'opentracing', '~> 0.5'
  spec.add_dependency 'opentelemetry-api'
  spec.add_dependency 'opentelemetry-sdk'
  spec.add_dependency 'opentelemetry-exporters-jaeger'
end
