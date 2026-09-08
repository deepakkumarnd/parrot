require 'spec_helper'

describe Parrot::Commands do
  let(:config)  { Parrot::Config.new(Dir.pwd, Logger.new(STDOUT)) }

  before do
    # create a new application
    Parrot::Commands::NewCommand.new(%w( blog ), config).run
  end

  after do
    # cleanup
    FileUtils.rm_rf('blog')
  end

  context 'BuildCommand' do
    it 'has a run method' do
      expect(Parrot::Commands::BuildCommand.new([], config)).to respond_to(:run)
    end

    context 'per-page head metadata' do
      let(:build_config) { Parrot::Config.new(File.join(Dir.pwd, 'blog'), Logger.new(File::NULL)) }

      before { Parrot::Commands::BuildCommand.new([], build_config).run }

      it 'sets the <title> from the post header' do
        expect(File.read('blog/public/post1.html')).to include('<title>About Parrot</title>')
      end

      it 'keeps the layout title on the index page' do
        expect(File.read('blog/public/index.html')).to include('<title>Parrot</title>')
      end

      it 'points og:url and canonical at each generated page' do
        post = File.read('blog/public/post2.html')
        expect(post).to include('<meta property="og:url" content="https://example.com/post2.html">')
        expect(post).to include('<link rel="canonical" href="https://example.com/post2.html">')
      end

      it 'points the index og:url and canonical at the site root' do
        index = File.read('blog/public/index.html')
        expect(index).to include('<meta property="og:url" content="https://example.com/">')
        expect(index).to include('<link rel="canonical" href="https://example.com/">')
      end

      it 'sets og:title per page from the same source as <title>' do
        expect(File.read('blog/public/post1.html')).to include('<meta property="og:title" content="About Parrot">')
        expect(File.read('blog/public/index.html')).to include('<meta property="og:title" content="Parrot">')
      end

      it 'rewrites a relative og:image to an absolute URL and ships the file' do
        expect(File.read('blog/public/post1.html'))
          .to include('<meta property="og:image" content="https://example.com/images/parrot.jpeg">')
        expect(File.exist?('blog/public/images/parrot.jpeg')).to be true
      end

      it 'keeps the Twitter Card tag from the layout' do
        expect(File.read('blog/public/post1.html')).to include('<meta name="twitter:card" content="summary_large_image">')
      end

      it 'marks posts as og:type article with an ISO article:published_time' do
        post = File.read('blog/public/post1.html')
        expect(post).to include('<meta property="og:type" content="article">')
        expect(post).to include('<meta property="article:published_time" content="2026-09-08">')
      end

      it 'keeps the index as og:type website with no article date' do
        index = File.read('blog/public/index.html')
        expect(index).to include('<meta property="og:type" content="website">')
        expect(index).not_to include('article:published_time')
      end

      it 'writes a sitemap.xml covering the index and every post' do
        sitemap = File.read('blog/public/sitemap.xml')
        expect(sitemap).to start_with('<?xml version="1.0" encoding="UTF-8"?>')
        expect(sitemap).to include('<loc>https://example.com/</loc>')
        expect(sitemap).to include('<loc>https://example.com/post1.html</loc>')
        expect(sitemap).to include('<loc>https://example.com/post2.html</loc>')
        expect(sitemap).to include('<lastmod>2026-09-08</lastmod>')
      end

      it 'writes a robots.txt pointing at the sitemap' do
        robots = File.read('blog/public/robots.txt')
        expect(robots).to include('User-agent: *')
        expect(robots).to include('Sitemap: https://example.com/sitemap.xml')
      end

      it 'sets <html lang> from the post header' do
        expect(File.read('blog/public/post1.html')).to include('<html lang="en">')
      end

      it 'loads app.js with defer and warms up the CDNs' do
        head = File.read('blog/public/post1.html')
        expect(head).to include('<script src="app.js" defer>')
        expect(head).to include('<link rel="preconnect" href="https://cdn.simplecss.org"')
        expect(head).to include('<link rel="preconnect" href="https://cdn.jsdelivr.net"')
      end

      it 'ships both favicon formats referenced from the layout' do
        expect(File.exist?('blog/public/images/favicon.ico')).to be true
        expect(File.exist?('blog/public/images/favicon.svg')).to be true
      end
    end

    context 'per-post language' do
      let(:build_config) { Parrot::Config.new(File.join(Dir.pwd, 'blog'), Logger.new(File::NULL)) }

      it 'uses the post header lang for that page only' do
        File.write('blog/views/posts/story.md', "<!--\ntitle: കഥ\nlang: ml\n-->\n\n# കഥ\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        expect(File.read('blog/public/story.html')).to include('<html lang="ml">')
        expect(File.read('blog/public/post1.html')).to include('<html lang="en">')
        expect(File.read('blog/public/index.html')).to include('<html lang="en">')
      end
    end
  end
end