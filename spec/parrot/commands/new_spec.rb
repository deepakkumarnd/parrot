require 'spec_helper'

describe Parrot::Commands do
  let(:config)  { Parrot::Config.new(Dir.pwd, Logger.new(STDOUT)) }

  context 'NewCommand' do
    it 'has a run method' do
      expect(Parrot::Commands::NewCommand.new(%w( foo ), config)).to respond_to(:run)
    end

    context 'Setup a blog' do
      let(:app_name) { 'my-test-blog' }

      after(:each) {
        FileUtils.rm_rf(app_name) if Dir.exist? app_name
      }

      it 'Verify all files from skeleton template is copied correctly' do
        Parrot::Commands::NewCommand.new([app_name], config).run
        
        expect(Dir.exist?(app_name)).to be true

        file_list = [
          "#{app_name}/config.yaml",
          "#{app_name}/css/app.scss",
          "#{app_name}/images/favicon.ico",
          "#{app_name}/images/favicon.svg", 
          "#{app_name}/images/apple-touch-icon.png",
          "#{app_name}/images/parrot.jpeg",
          "#{app_name}/javascripts/app.js",
          "#{app_name}/public/.keep",
          "#{app_name}/views/404.md",
          "#{app_name}/views/layout.html.erb",
          "#{app_name}/views/posts/about_parrot.md",
          "#{app_name}/views/posts/sample.md"
        ]

        expect(file_list.all? { |file| File.exist?(file) }).to be true
      end
    end
  end
end
