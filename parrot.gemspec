# coding: utf-8
require_relative 'lib/parrot/version'

Gem::Specification.new do |spec|
  spec.name          = 'parrot'
  spec.version       = Parrot::VERSION
  spec.authors       = ['Deepak']
  spec.email         = ['deepakkumarnd@gmail.com']
  spec.description   = 'A simple website/blog builder for ruby lovers'
  spec.summary       = 'A simple website/blog builder for ruby lovers'
  spec.homepage      = 'https://github.com/42races/parrot'
  spec.license       = 'MIT'

  # Runtime Dependencies
  spec.add_dependency 'tilt'
  spec.add_dependency 'sassc'
  spec.add_dependency 'watchr'
  spec.add_dependency 'nokogiri'
  spec.add_dependency 'webrick'
  spec.add_dependency 'kramdown'
  spec.add_dependency 'logger'
  spec.add_dependency 'observer'

  # File Management
  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  # Development Dependencies
  spec.add_development_dependency 'bundler', '>= 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'pry'
end