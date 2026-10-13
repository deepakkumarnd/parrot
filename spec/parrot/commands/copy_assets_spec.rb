require 'spec_helper'

describe Parrot::Commands do
  let(:config) { Parrot::Config.new(File.expand_path('blog'), TestLogger) }
  let(:command) { Parrot::Commands::CopyAssetsCommand.new([], config) }
  let(:files) do
    %w[css/_search.scss css/_copy_code.scss css/_menu.scss
       images/copy-icon.svg images/favicon.ico images/favicon.svg images/apple-touch-icon.png]
  end

  before do
    FileUtils.rm_rf('blog')
    Parrot::Commands::NewCommand.new(%w[blog], config).run
  end

  after do
    FileUtils.rm_rf('blog')
  end

  context 'CopyAssetsCommand' do
    it 'copies in the skeleton styles and icons the blog is missing' do
      files.each { |file| File.delete("blog/#{file}") }

      expect { command.run }.to output(files.map { |file| "Copied #{file}\n" }.join).to_stdout
      files.each do |file|
        expect(File.binread("blog/#{file}")).to eq(File.binread(File.join(Parrot::Skeleton::DIR, file)))
      end
    end

    it 'never overwrites a file the blog already has' do
      File.write('blog/css/_menu.scss', ".menu { color: red; }\n")
      File.delete('blog/css/_search.scss')

      expect { command.run }.to output("Copied css/_search.scss\n").to_stdout
      expect(File.read('blog/css/_menu.scss')).to eq(".menu { color: red; }\n")
    end

    it 'says so when there is nothing to copy' do
      expect { command.run }.to output("Nothing to copy, the blog has every asset.\n").to_stdout
    end

    it 'copies no scripts, config.yaml or layout' do
      FileUtils.rm_rf('blog/javascripts')
      files.each { |file| File.delete("blog/#{file}") }
      before = %w[config.yaml views/layout.html.erb].to_h { |file| [file, File.read("blog/#{file}")] }

      expect { command.run }.to output.to_stdout
      expect(Dir.exist?('blog/javascripts')).to be false
      before.each { |file, content| expect(File.read("blog/#{file}")).to eq(content) }
    end

    it 'fails outside a blog' do
      outside = Parrot::Config.new(File.expand_path('blog/views'), TestLogger)

      expect { Parrot::Commands::CopyAssetsCommand.new([], outside).run }.to raise_error(/Run this from the blog's root/)
    end
  end
end
