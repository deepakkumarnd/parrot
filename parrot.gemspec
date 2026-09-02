# coding: utf-8
require_relative 'lib/parrot/version'
require 'bundler'

Gem::Specification.new do |spec|
  spec.name          = 'parrot'
  spec.version       = Parrot::VERSION
  spec.authors       = %w(Deepak)
  spec.email         = %w(deepakkumarnd@gmail.com)
  spec.description   = %q{ A simple website/blog builder for ruby lovers }
  spec.summary       = %q{ A simple website/blog builder for ruby lovers }
  spec.homepage      = 'github.com/42races/parrot'
  spec.license       = 'MIT'

  # --- AUTOMATIC DEPENDENCY INJECTION ---
  # Define which gems are strictly for development / testing
  dev_gems = %w[rspec watchr pry]

  Bundler.definition.dependencies.each do |dep|
    next if dep.name == spec.name # Prevent self-dependency

    if dev_gems.include?(dep.name)
      spec.add_development_dependency(dep.name, dep.requirement)
    else
      spec.add_dependency(dep.name, dep.requirement)
    end
  end
  # ---------------------------------------

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = %w(lib)

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
end