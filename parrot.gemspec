require_relative 'lib/parrot/metadata'

Gem::Specification.new do |spec|
  spec.name          = 'parrot'
  spec.version       = Parrot::VERSION
  spec.authors       = ['Deepak Kumar']
  spec.email         = ['deepakkumarnd@gmail.com']
  spec.summary       = 'A static markdown blog builder written in ruby for minimalist bloggers'
  spec.description   = 'A static blogging tool written in ruby, posts are in markdown format'
  spec.homepage      = Parrot::HOMEPAGE
  spec.license       = 'MIT'

  # Runtime Dependencies
  spec.add_dependency 'kramdown'
  spec.add_dependency 'kramdown-parser-gfm'
  spec.add_dependency 'logger'
  spec.add_dependency 'nokogiri'
  spec.add_dependency 'observer'
  spec.add_dependency 'rouge'
  spec.add_dependency 'sassc'
  spec.add_dependency 'tilt'
  spec.add_dependency 'watchr'
  spec.add_dependency 'webrick'

  # File Management
  spec.bindir = 'exe'
  spec.executables   = 'parrot'
  spec.files         = `git ls-files`.split("\n")
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.2'

  spec.post_install_message = <<~MESSAGE
    Refer to readme at README.md to know how to get started with Parrot
  MESSAGE
  spec.metadata['rubygems_mfa_required'] = 'true'
end
