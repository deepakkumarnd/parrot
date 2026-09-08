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

      it 'fills description, og:description and twitter:description from the first paragraph' do
        head = File.read('blog/public/post1.html')
        summary = 'Parrot turns a folder of Markdown into a static blog.'
        expect(head).to include(%(<meta name="description" content="#{summary}))
        expect(head).to include(%(<meta property="og:description" content="#{summary}))
        expect(head).to include(%(<meta name="twitter:description" content="#{summary}))
      end

      it 'maps lang onto og:locale' do
        expect(File.read('blog/public/post1.html')).to include('<meta property="og:locale" content="en_US">')
      end

      it 'renders exactly one <h1> per page' do
        %w[index post1 post2].each do |name|
          expect(File.read("blog/public/#{name}.html").scan('<h1').size).to eq(1)
        end
      end

      it 'embeds BlogPosting JSON-LD on posts' do
        data = JSON.parse(File.read('blog/public/post1.html')[%r{<script type="application/ld\+json">(.+?)</script>}m, 1])
        expect(data['@type']).to eq('BlogPosting')
        expect(data['headline']).to eq('About Parrot')
        expect(data['datePublished']).to eq('2026-09-08')
        expect(data['author']['name']).to eq('Your name')
      end

      it 'embeds WebSite JSON-LD on the index' do
        data = JSON.parse(File.read('blog/public/index.html')[%r{<script type="application/ld\+json">(.+?)</script>}m, 1])
        expect(data['@type']).to eq('WebSite')
        expect(data['url']).to eq('https://example.com/')
      end

      it 'writes an RSS feed and links it for autodiscovery' do
        feed = File.read('blog/public/feed.xml')
        expect(feed).to include('<rss version="2.0"')
        expect(feed).to include('<link>https://example.com/post1.html</link>')
        expect(feed).to include('<pubDate>Tue, 08 Sep 2026 00:00:00 -0000</pubDate>')
        expect(File.read('blog/public/post1.html'))
          .to include('<link rel="alternate" type="application/rss+xml" title="Parrot" href="https://example.com/feed.xml">')
      end

      it 'emits og:image:width/height read from the image file' do
        head = File.read('blog/public/post1.html')
        expect(head).to include('<meta property="og:image:width" content="1024">')
        expect(head).to include('<meta property="og:image:height" content="1024">')
      end

      it 'gives the sitemap index entry the newest post date as <lastmod>' do
        sitemap = File.read('blog/public/sitemap.xml')
        expect(sitemap).to match(%r{<loc>https://example\.com/</loc>\s*<lastmod>2026-09-08</lastmod>})
      end

      it 'builds a noindex 404 page with a parrot image, outside the sitemap and feed' do
        page = File.read('blog/public/404.html')
        expect(page).to include('<title>Page not found</title>')
        expect(page).to include('<meta name="robots" content="noindex">')
        expect(page).to include('images/parrot.jpeg')
        expect(page.scan('<h1').size).to eq(1)
        expect(File.exist?('blog/public/images/parrot.jpeg')).to be true

        expect(File.read('blog/public/sitemap.xml')).not_to include('404.html')
        expect(File.read('blog/public/feed.xml')).not_to include('404.html')
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

    context 'post header description' do
      let(:build_config) { Parrot::Config.new(File.join(Dir.pwd, 'blog'), Logger.new(File::NULL)) }

      it 'wins over the first-paragraph fallback' do
        File.write('blog/views/posts/story.md',
                   "<!--\ntitle: A story\ndescription: Hand-written summary.\n-->\n\n# A story\n\nThe opening paragraph.\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        head = File.read('blog/public/story.html')
        expect(head).to include('<meta name="description" content="Hand-written summary.">')
        expect(head).to include('<meta property="og:description" content="Hand-written summary.">')
      end
    end
  end
end