require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:run_version_spec) do |t|
  # Specify the path to the specific test file you want to run
  t.pattern = 'spec/parrot/version_spec.rb' 
end

desc "Bump version"
task :bump_patch_version do
    require_relative 'lib/parrot/version'
    puts("Current version = #{Parrot::VERSION}")
    major, minor, patch = Parrot::VERSION.split('.').map(&:to_i)
    patch = patch + 1
    new_version = [major, minor, patch].map(&:to_s).join('.')
    puts("New version = #{new_version}")
    # Update version file
    contents = File.read("lib/parrot/version.rb")
    contents.sub!(Parrot::VERSION, new_version)
    File.write("lib/parrot/version.rb", contents)
    # Update version spec
    contents = File.read("spec/parrot/version_spec.rb")
    contents.sub!(Parrot::VERSION, new_version)
    File.write("spec/parrot/version_spec.rb", contents)
    Rake::Task['run_version_spec'].invoke
end