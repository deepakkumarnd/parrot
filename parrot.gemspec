# coding: utf-8
require_relative 'lib/parrot/version'

Gem::Specification.new do |spec|
  spec.name          = 'parrot'
  spec.version       = Parrot::VERSION
  spec.authors       = ['Deepak Kumar']
  spec.email         = ['deepakkumarnd@gmail.com']
  spec.summary       = 'A static markdown blog builder written in ruby for minimalist bloggers'
  spec.description   = 'A static blogging tool written in ruby, posts are in markdown format'
  spec.homepage      = 'https://github.com/42races/parrot'
  spec.license       = 'MIT'

  # Runtime Dependencies
  spec.add_dependency 'tilt'
  spec.add_dependency 'sassc'
  spec.add_dependency 'watchr'
  spec.add_dependency 'nokogiri'
  spec.add_dependency 'webrick'
  spec.add_dependency 'kramdown'
  spec.add_dependency 'kramdown-parser-gfm'
  spec.add_dependency 'rouge'
  spec.add_dependency 'logger'
  spec.add_dependency 'observer'

  # File Management
  spec.bindir = 'exe'
  spec.executables   = 'parrot'
  spec.files         = `git ls-files`.split($/)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  # Development Dependencies
  spec.add_development_dependency 'bundler', '>= 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'pry'

  spec.post_install_message = <<~MESSAGE
    Refer to readme at README.md to know how to get started with Parrot
  MESSAGE
end