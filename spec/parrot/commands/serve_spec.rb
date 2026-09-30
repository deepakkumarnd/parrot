require 'net/http'

describe Parrot::Commands do
  let(:config) { Parrot::Config.new(Dir.pwd, TestLogger) }

  before do
    # create a new application
    Parrot::Commands::NewCommand.new(%w[blog], config).run
  end

  after do
    # cleanup
    FileUtils.rm_rf('blog')
  end

  context 'ServeCommand' do
    it 'has a run method' do
      expect(Parrot::Commands::ServeCommand.new([], config)).to respond_to(:run)
    end

    it 'run a webserver at port 8000 serving files' do
      # Parrot::Commands::ServeCommand.new([]).run
    end
  end

  context 'ServeCommand::FileHandler' do
    let(:document_root) { File.expand_path('blog/public') }

    before do
      FileUtils.mkdir_p(document_root)
      File.write(File.join(document_root, 'index.html'), 'home page')
      @server = WEBrick::HTTPServer.new(Port: 0, Logger: WEBrick::Log.new(File::NULL), AccessLog: [])
      @server.mount('/', Parrot::Commands::ServeCommand::FileHandler, document_root)
      @thread = Thread.new { @server.start }
      @port = @server.config[:Port]
    end

    after do
      @server.shutdown
      @thread.join
    end

    def get(path)
      Net::HTTP.get_response(URI("http://127.0.0.1:#{@port}#{path}"))
    end

    it 'serves existing files' do
      response = get('/index.html')
      expect(response.code).to eq('200')
      expect(response.body).to eq('home page')
    end

    it 'answers a missing path with the built 404.html and a 404 status' do
      File.write(File.join(document_root, '404.html'), 'custom not found')
      response = get('/missing')
      expect(response.code).to eq('404')
      expect(response.body).to eq('custom not found')
    end

    it "falls back to WEBrick's error page when no 404.html was built" do
      response = get('/missing')
      expect(response.code).to eq('404')
      expect(response.body).to include('Not Found')
    end
  end
end
