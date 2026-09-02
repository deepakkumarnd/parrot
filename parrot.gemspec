# coding: utf-8
require_relative 'lib/parrot/version'

Gem::Specification.new do |spec|
  spec.name          = 'parrot'
  spec.version       = Parrot::VERSION
  spec.authors       = %w(Deepak)
  spec.email         = %w(deepakkumarnd@gmail.com)
  spec.description   = %q{ A build web front end build tool for ruby lovers using slim, coffee and scss }
  spec.summary       = %q{ A build web front end build tool for ruby lovers using slim, coffee and scss }
  spec.homepage      = 'github.com/42races/parrot'
  spec.license       = 'MIT'
  spec.add_dependency 'tilt'
  spec.add_dependency 'nokogiri'
  spec.add_dependency 'sassc'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = %w(lib)

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
end
