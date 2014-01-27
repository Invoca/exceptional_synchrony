require File.expand_path('../lib/exceptional_synchrony/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'exceptional_synchrony'
  s.date        = '2014-01-16'
  s.summary     = 'Extensions to EventMachine/Synchrony to work well with exceptions'
  s.description = %q{}
  s.authors     = ['Colin Kelley']
  s.email       = 'colin@invoca.com'
  s.homepage    = 'https://github.com/Invoca/exceptional_synchrony'
  s.license     = 'MIT'
  s.files       = `git ls-files`.split($/)
  s.version     = ExceptionalSynchrony::VERSION

  s.add_runtime_dependency 'eventmachine', '~> 1.0.3'
  s.add_runtime_dependency 'em-synchrony', '~> 1.0.3'

  s.add_development_dependency 'rr', '~> 1.1.2'
  s.add_development_dependency 'webmock', '~> 1.17.1'
end
