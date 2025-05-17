require 'spec_helper'

describe Parrot::Commands do
  let(:config)  { Parrot::Config.new(Dir.pwd, Logger.new(STDOUT)) }

  context 'NewCommand' do
    it 'has a run method' do
      expect(Parrot::Commands::NewCommand.new(%w( foo ), config)).to respond_to(:run)
    end

    it 'creates a blog application' do
      Parrot::Commands::NewCommand.new(%w( blog ), config).run
      expect(Dir.exist?('blog')).to be true

      file_list = %w[blog/css/app.scss blog/javascripts/app.js blog/images/favicon.ico blog/images/favicon-16x16.png blog/images/favicon-32x32.png blog/images/favicon-96x96.png blog/views/layout.html.erb blog/views/index.md blog/views/posts/post1.md blog/views/posts/post2.md blog/public/.keep]

      expect(file_list.all? { |file| File.exist?(file) }).to be true
      # cleanup
      FileUtils.rm_rf('blog')
    end
  end
end
