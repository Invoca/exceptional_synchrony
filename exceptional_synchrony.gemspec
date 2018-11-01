require File.expand_path('../lib/exceptional_synchrony/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name        = 'exceptional_synchrony'
  gem.date        = '2014-01-16'
  gem.summary     = 'Extensions to EventMachine/Synchrony to work well with exceptions'
  gem.description = %q{}
  gem.authors     = ['Colin Kelley']
  gem.email       = 'colin@invoca.com'
  gem.homepage    = 'https://github.com/Invoca/exceptional_synchrony'
  gem.license     = 'MIT'
  gem.files       = `git ls-files`.split($/)
  gem.version     = ExceptionalSynchrony::VERSION

  gem.add_dependency 'exception_handling', '~> 2.0'
  gem.add_dependency 'eventmachine'
  gem.add_dependency 'em-synchrony'
  gem.add_dependency 'em-http-request'
  gem.add_dependency 'hobo_support'

  gem.add_development_dependency 'thor'
  gem.add_development_dependency 'minitest'
  gem.add_development_dependency 'webmock', '~> 1.17.1'
  gem.add_development_dependency 'rr', '~> 1.1.2'
  gem.add_development_dependency 'pry'
end
