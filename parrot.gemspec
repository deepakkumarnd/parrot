# coding: utf-8
require_relative 'lib/parrot/version'

Gem::Specification.new do |spec|
  spec.name          = 'parrot'
  spec.version       = Parrot::VERSION
  spec.authors       = %w(Deepak)
  spec.email         = %w(deepakkumarnd@gmail.com)
  spec.description   = %q{ A simple website/blog builder for ruby lovers }
  spec.summary       = %q{ A simple website/blog builder for ruby lovers }
  spec.homepage      = 'github.com/42races/parrot'
  spec.license       = 'MIT'

  # --- LOOP-SAFE PURE TEXT GEMFILE PARSING ---
  gemfile_path = File.expand_path('../Gemfile', __FILE__)

  if File.exist?(gemfile_path)
    # Define which gems are strictly for development / testing
    dev_gems = %w[rspec watchr pry]

    File.readlines(gemfile_path).each do |line|
      # Match lines that look like: gem 'name' or gem "name"
      if line =~ /^\s*gem\s+['"]([^'"]+)['"]/
        gem_name = $1
        next if gem_name == spec.name # Prevent self-dependency loop

        if dev_gems.include?(gem_name)
          spec.add_development_dependency(gem_name)
        else
          spec.add_dependency(gem_name)
        end
      end
    end
  end
  # --------------------------------------------

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = %w(lib)

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
end
