require 'open3'
require 'spec_helper'

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

  context 'BuildCommand' do
    it 'has a run method' do
      expect(Parrot::Commands::BuildCommand.new([], config)).to respond_to(:run)
    end

    context 'per-page head metadata' do
      let(:build_config) { Parrot::Config.new(File.join(Dir.pwd, 'blog'), TestLogger) }

      before { Parrot::Commands::BuildCommand.new([], build_config).run }

      it 'sets the <title> from the post header' do
        expect(File.read('blog/public/about_parrot.html')).to include('<title>About Parrot</title>')
      end

      it 'keeps the layout title on the index page' do
        expect(File.read('blog/public/index.html')).to include('<title>Parrot</title>')
      end

      it 'points og:url and canonical at each generated page' do
        post = File.read('blog/public/sample.html')
        expect(post).to include('<meta property="og:url" content="https://example.com/sample.html">')
        expect(post).to include('<link rel="canonical" href="https://example.com/sample.html">')
      end

      it 'points the index og:url and canonical at the site root' do
        index = File.read('blog/public/index.html')
        expect(index).to include('<meta property="og:url" content="https://example.com/">')
        expect(index).to include('<link rel="canonical" href="https://example.com/">')
      end

      it 'sets og:title per page from the same source as <title>' do
        expect(File.read('blog/public/about_parrot.html')).to include('<meta property="og:title" content="About Parrot">')
        expect(File.read('blog/public/index.html')).to include('<meta property="og:title" content="Parrot">')
      end

      it 'rewrites a relative og:image to an absolute URL and ships the file' do
        expect(File.read('blog/public/about_parrot.html'))
          .to include('<meta property="og:image" content="https://example.com/images/parrot.jpeg">')
        expect(File.exist?('blog/public/images/parrot.jpeg')).to be true
      end

      it 'keeps the Twitter Card tag from the layout' do
        expect(File.read('blog/public/about_parrot.html')).to include('<meta name="twitter:card" content="summary_large_image">')
      end

      it 'marks posts as og:type article with an ISO article:published_time' do
        post = File.read('blog/public/about_parrot.html')
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
        expect(sitemap).to include('<loc>https://example.com/about_parrot.html</loc>')
        expect(sitemap).to include('<loc>https://example.com/sample.html</loc>')
        expect(sitemap).to include('<lastmod>2026-09-08</lastmod>')
      end

      it 'writes a robots.txt pointing at the sitemap' do
        robots = File.read('blog/public/robots.txt')
        expect(robots).to include('User-agent: *')
        expect(robots).to include('Sitemap: https://example.com/sitemap.xml')
      end

      it 'sets <html lang> from the post header' do
        expect(File.read('blog/public/about_parrot.html')).to include('<html lang="en">')
      end

      it 'loads app.js with defer and warms up the CDNs' do
        head = File.read('blog/public/about_parrot.html')
        expect(head).to include('<script src="app.js" defer>')
        expect(head).to include('<link rel="preconnect" href="https://cdn.simplecss.org"')
        expect(head).to include('<link rel="preconnect" href="https://cdn.jsdelivr.net"')
      end

      it 'ships every icon referenced from the layout' do
        expect(File.exist?('blog/public/images/favicon.ico')).to be true
        expect(File.exist?('blog/public/images/favicon.svg')).to be true
        expect(File.exist?('blog/public/images/apple-touch-icon.png')).to be true
      end

      it 'fills description, og:description and twitter:description from the first paragraph' do
        head = File.read('blog/public/about_parrot.html')
        summary = 'Parrot turns a folder of Markdown into a static blog.'
        expect(head).to include(%(<meta name="description" content="#{summary}))
        expect(head).to include(%(<meta property="og:description" content="#{summary}))
        expect(head).to include(%(<meta name="twitter:description" content="#{summary}))
      end

      it 'maps lang onto og:locale' do
        expect(File.read('blog/public/about_parrot.html')).to include('<meta property="og:locale" content="en_US">')
      end

      it 'renders exactly one <h1> per page' do
        %w[about_parrot sample].each do |name|
          expect(File.read("blog/public/#{name}.html").scan('<h1').size).to eq(1)
        end
      end

      it 'links back to the index from the top of each post, but not from the index itself' do
        post = File.read('blog/public/about_parrot.html')
        expect(post).to match(%r{<main>\s*<p class="back-link"><a href="index\.html">.*?</a></p>})

        expect(File.read('blog/public/index.html')).not_to include('back-link')
      end

      it 'embeds BlogPosting JSON-LD on posts' do
        data = JSON.parse(File.read('blog/public/about_parrot.html')[%r{<script type="application/ld\+json">(.+?)</script>}m, 1])
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
        expect(feed).to include('<link>https://example.com/about_parrot.html</link>')
        expect(feed).to include('<pubDate>Tue, 08 Sep 2026 00:00:00 -0000</pubDate>')
        expect(File.read('blog/public/about_parrot.html'))
          .to include('<link rel="alternate" type="application/rss+xml" title="Parrot" href="https://example.com/feed.xml">')
      end

      it 'emits og:image:width/height read from the image file' do
        head = File.read('blog/public/about_parrot.html')
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
        expect(File.read('blog/public/about_parrot.html')).to include('<html lang="en">')
        expect(File.read('blog/public/index.html')).to include('<html lang="en">')
      end
    end

    context 'draft posts' do
      let(:build_config) { Parrot::Config.new(File.join(Dir.pwd, 'blog'), Logger.new(File::NULL)) }

      it 'builds draft posts while editing posts' do
        File.write('blog/views/posts/story.md', "<!--\ntitle: Story\ndraft: true\n-->\n\n# story\n")
        builder = Parrot::Commands::BuildCommand.new([], build_config)
        builder.unset_build_mode!
        builder.run

        expect(File.read('blog/public/story.html')).to include('<html lang="en">')
        expect(File.read('blog/public/about_parrot.html')).to include('<html lang="en">')
        expect(File.read('blog/public/index.html')).to include('<html lang="en">')
      end

      it 'skip draft posts while building posts' do
        File.write('blog/views/posts/story.md', "<!--\ntitle: Story\ndraft: true\n-->\n\n# story\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        expect(File.exist?('blog/public/story.html')).to be false
        expect(File.read('blog/public/about_parrot.html')).to include('<html lang="en">')
        expect(File.read('blog/public/index.html')).to include('<html lang="en">')
      end

      it 'leaves skipped drafts out of the index listing, sitemap and feed' do
        File.write('blog/views/posts/story.md', "<!--\ntitle: Story\ndate: 01/10/2026\ndraft: true\n-->\n\n# story\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        %w[index.html sitemap.xml feed.xml].each do |name|
          expect(File.read("blog/public/#{name}")).not_to include('story.html')
        end
      end

      it 'lists drafts in the index listing, sitemap and feed while editing, since they are built' do
        File.write('blog/views/posts/story.md', "<!--\ntitle: Story\ndate: 01/10/2026\ndraft: true\n-->\n\n# story\n")
        builder = Parrot::Commands::BuildCommand.new([], build_config)
        builder.unset_build_mode!
        builder.run

        %w[index.html sitemap.xml feed.xml].each do |name|
          expect(File.read("blog/public/#{name}")).to include('story.html')
        end
      end
    end

    context 'post tags' do
      let(:build_config) { Parrot::Config.new(File.join(Dir.pwd, 'blog'), Logger.new(File::NULL)) }

      def build_story(header)
        File.write('blog/views/posts/story.md', "<!--\ntitle: Story\ndate: 01/01/2012\n#{header}-->\n\n# story\n\nSome text.\n")
        Parrot::Commands::BuildCommand.new([], build_config).run
        Nokogiri::HTML(File.read('blog/public/story.html'))
      end

      it 'lists the header tags at the bottom of the post' do
        html = build_story("tags: algorithms, coding\n")

        last = html.at('main').element_children.last
        expect(last.name).to eq('p')
        expect(last['class']).to eq('post-tags')
        expect(last.css('span.tag').map(&:text)).to eq(%w[algorithms coding])
      end

      it 'trims tags and drops blanks and duplicates' do
        html = build_story("tags: a, , b ,a\n")

        expect(html.css('.post-tags span.tag').map(&:text)).to eq(%w[a b])
      end

      it 'adds nothing to posts without tags or to the index' do
        html = build_story('')

        expect(html.at('.post-tags')).to be_nil
        expect(File.read('blog/public/index.html')).not_to include('post-tags')
      end

      it 'emits article:tag metas and JSON-LD keywords' do
        html = build_story("tags: algorithms, coding\n")

        expect(html.css('head meta[property="article:tag"]').map { |m| m['content'] }).to eq(%w[algorithms coding])
        json = JSON.parse(html.at('script[type="application/ld+json"]').text)
        expect(json['keywords']).to eq('algorithms, coding')
      end
    end

    context 'generated post index listing' do
      let(:build_config) { Parrot::Config.new(File.join(Dir.pwd, 'blog'), Logger.new(File::NULL)) }

      it 'lists posts newest first using the default format, with no views/index.md' do
        expect(File.exist?('blog/views/index.md')).to be false

        File.write('blog/views/posts/oldest.md', "<!--\ntitle: Oldest\ndate: 01/01/2020\n-->\n\n# Oldest\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        index = File.read('blog/public/index.html')
        about_pos = index.index('about_parrot.html')
        sample_pos = index.index('sample.html')
        oldest_pos = index.index('oldest.html')

        # the default list_format's {post_date} goes through
        # post_date_format.on_list ("%m/%Y" by default), not the raw header date
        expect(index).to include('09/2026')
        expect(index).to include('01/2020')
        expect([about_pos, sample_pos]).to all(be < oldest_pos)
      end

      it 'titles the index page from config.yaml post_listing.list_title' do
        Parrot::Commands::BuildCommand.new([], build_config).run
        expect(File.read('blog/public/index.html')).to include('<h3>Post listing</h3>')

        File.write('blog/config.yaml', "post_listing:\n  list_title: \"Latest writing\"\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        expect(File.read('blog/public/index.html')).to include('<h3>Latest writing</h3>')
      end

      it 'omits the index heading entirely when list_title is empty' do
        File.write('blog/config.yaml', "post_listing:\n  list_title: \"\"\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        index = File.read('blog/public/index.html')
        expect(index).not_to include('<h1')
      end

      it 'uses config.yaml post_listing.back_link_text for the post back link' do
        File.write('blog/config.yaml', "post_listing:\n  back_link_text: \"Home\"\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        expect(File.read('blog/public/about_parrot.html')).to include('<p class="back-link"><a href="index.html">Home</a></p>')
      end

      it 'omits the post back link entirely when back_link_text is empty' do
        File.write('blog/config.yaml', "post_listing:\n  back_link_text: \"\"\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        expect(File.read('blog/public/about_parrot.html')).not_to include('back-link')
      end

      it 'honours a custom list_format from config.yaml' do
        File.write('blog/config.yaml', "post_listing:\n  list_format: \"{post_title} -- {%A, %B %d %Y}\"\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        index = File.read('blog/public/index.html')
        expect(index).to include('Tuesday, September 08 2026')
      end

      it 'links only the title when {post_link} wraps just {post_title}' do
        File.write('blog/config.yaml', "post_listing:\n  list_format: \"{%d/%m} ~ [{post_title}]({post_link})\"\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        index = File.read('blog/public/index.html')
        expect(index).to include('08/09 ~ <a href="about_parrot.html">About Parrot</a>')
      end

      it 'links the whole line when {post_link} wraps the entire format' do
        File.write('blog/config.yaml', "post_listing:\n  list_format: \"[{%d/%m} ~ {post_title}]({post_link})\"\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        index = File.read('blog/public/index.html')
        expect(index).to include('<a href="about_parrot.html">08/09 ~ About Parrot</a>')
      end

      it 'exposes any custom header field as {post_<key>}' do
        File.write('blog/config.yaml', "post_listing:\n  list_format: \"{post_title} [{post_category}]\"\n")
        File.write('blog/views/posts/story.md', "<!--\ntitle: A story\ncategory: Fiction\n-->\n\n# A story\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        index = File.read('blog/public/index.html')
        expect(index).to include('A story [Fiction]')
      end

      it 'formats {post_date} in list_format per post_date_format.on_list' do
        File.write('blog/config.yaml',
                   "post_listing:\n  list_format: \"{post_date} ~ {post_title}\"\npost_date_format:\n  on_list: \"%m/%Y\"\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        index = File.read('blog/public/index.html')
        expect(index).to include('09/2026 ~ About Parrot')
      end

      it 'formats a literal {post_date} inside a post body per post_date_format.on_post' do
        File.write('blog/config.yaml', "post_date_format:\n  on_post: \"%A, %B %d %Y\"\n")
        File.write('blog/views/posts/story.md', "<!--\ntitle: A story\ndate: 08/09/2026\n-->\n\n# A story\n\n_{post_date}_\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        expect(File.read('blog/public/story.html')).to include('Tuesday, September 08 2026')
      end

      it 'groups posts by year under a heading when group_by is year' do
        File.write('blog/config.yaml', "post_listing:\n  group_by: year\n")
        File.write('blog/views/posts/old.md', "<!--\ntitle: Old\ndate: 01/01/2020\n-->\n\n# Old\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        index = File.read('blog/public/index.html')
        expect(index).to include('<h2>2026</h2>')
        expect(index).to include('<h2>2020</h2>')
        expect(index.index('2026</h2>')).to be < index.index('2020</h2>')
      end
    end

    context 'post index pagination' do
      let(:build_config) { Parrot::Config.new(File.join(Dir.pwd, 'blog'), Logger.new(File::NULL)) }

      it 'keeps every post on a single index.html when per_page is unset' do
        Parrot::Commands::BuildCommand.new([], build_config).run
        expect(File.exist?('blog/public/index2.html')).to be false
      end

      it 'splits the listing across index.html, index2.html, etc. once per_page is exceeded' do
        File.write('blog/config.yaml', "post_listing:\n  per_page: 1\n")
        File.write('blog/views/posts/oldest.md', "<!--\ntitle: Oldest\ndate: 01/01/2020\n-->\n\n# Oldest\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        expect(File.exist?('blog/public/index.html')).to be true
        expect(File.exist?('blog/public/index2.html')).to be true
        expect(File.exist?('blog/public/index3.html')).to be true
        expect(File.exist?('blog/public/index4.html')).to be false
        expect(File.read('blog/public/index3.html')).to include('oldest.html')
      end

      it 'links older/newer pages with the default pager text' do
        File.write('blog/config.yaml', "post_listing:\n  per_page: 1\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        page1 = File.read('blog/public/index.html')
        expect(page1).to include('<a href="index2.html">Older posts →</a>')
        expect(page1).not_to include('Newer posts')

        page2 = File.read('blog/public/index2.html')
        expect(page2).to include('<a href="index.html">← Newer posts</a>')
        expect(page2).not_to include('Older posts')
      end

      it 'honours custom newer_link_text/older_link_text from config.yaml' do
        File.write('blog/config.yaml',
                   "post_listing:\n  per_page: 1\n  newer_link_text: \"Prev\"\n  older_link_text: \"Next\"\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        expect(File.read('blog/public/index.html')).to include('>Next<')
        expect(File.read('blog/public/index2.html')).to include('>Prev<')
      end

      it 'omits the pager entirely when the only applicable link text is set to empty' do
        File.write('blog/config.yaml', "post_listing:\n  per_page: 1\n  older_link_text: \"\"\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        expect(File.read('blog/public/index.html')).not_to include('pagination')
      end

      it 'omits the list_title heading on pages after the first' do
        File.write('blog/config.yaml', "post_listing:\n  per_page: 1\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        expect(File.read('blog/public/index.html')).to include('<h3')
        expect(File.read('blog/public/index2.html')).not_to include('<h3')
      end

      it "points a pushed-down post's back-link at the index page it actually appears on" do
        File.write('blog/config.yaml', "post_listing:\n  per_page: 1\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        main_html = File.read('blog/public/index2.html')[%r{<main>.*?</main>}m]
        pushed_post = main_html[/href="([^"]+\.html)"/, 1]
        expect(File.read("blog/public/#{pushed_post}"))
          .to include(%(<a href="index2.html">← Back to all posts</a>))
      end

      it 'removes a stale trailing index page once the post count drops back below per_page' do
        File.write('blog/config.yaml', "post_listing:\n  per_page: 1\n")
        Parrot::Commands::BuildCommand.new([], build_config).run
        expect(File.exist?('blog/public/index2.html')).to be true

        File.write('blog/config.yaml', "post_listing:\n  per_page: 10\n")
        Parrot::Commands::BuildCommand.new([], build_config).run
        expect(File.exist?('blog/public/index2.html')).to be false
      end

      it 'lists every index page in the sitemap' do
        File.write('blog/config.yaml', "post_listing:\n  per_page: 1\n")
        Parrot::Commands::BuildCommand.new([], build_config).run

        sitemap = File.read('blog/public/sitemap.xml')
        expect(sitemap).to include('<loc>https://example.com/</loc>')
        expect(sitemap).to include('<loc>https://example.com/index2.html</loc>')
      end

      it 'rewrites the sitemap when the watcher rebuilds after per_page changes in config.yaml' do
        command = Parrot::Commands::BuildCommand.new([], build_config)
        command.run
        expect(File.read('blog/public/sitemap.xml')).not_to include('index2.html')

        File.write('blog/config.yaml', "post_listing:\n  per_page: 1\n")
        command.build('config.yaml')

        expect(File.read('blog/public/sitemap.xml')).to include('<loc>https://example.com/index2.html</loc>')
      end

      it "updates a pushed post's back-link when the watcher rebuilds after a new post shifts pagination" do
        File.write('blog/config.yaml', "post_listing:\n  per_page: 1\n")
        command = Parrot::Commands::BuildCommand.new([], build_config)
        command.run

        new_post = 'blog/views/posts/newest.md'
        File.write(new_post, "<!--\ntitle: Newest\ndate: 01/01/2027\n-->\n\n# Newest\n")
        command.build(new_post)

        main_html = File.read('blog/public/index2.html')[%r{<main>.*?</main>}m]
        pushed_post = main_html[/href="([^"]+\.html)"/, 1]
        expect(File.read("blog/public/#{pushed_post}")).to include('<a href="index2.html">')
      end
    end

    context 'about page' do
      let(:build_config) { Parrot::Config.new(File.join(Dir.pwd, 'blog'), Logger.new(File::NULL)) }
      let(:command) { Parrot::Commands::BuildCommand.new([], build_config) }

      before { command.run }

      it 'builds about.html with its own title, description and social links' do
        page = File.read('blog/public/about.html')
        expect(page).to include('<title>About</title>')
        expect(page).to include('<meta name="description" content="Who writes this blog, and where else to find them.">')
        expect(page).to include('<meta property="og:url" content="https://example.com/about.html">')
        expect(page).to include('href="https://github.com/your-username"')
        expect(page.scan('<h1').size).to eq(1)
      end

      it 'is an AboutPage, not an article' do
        page = File.read('blog/public/about.html')
        expect(page).to include('<meta property="og:type" content="website">')
        expect(page).not_to include('article:published_time')
        expect(page).to include('"@type": "AboutPage"')
      end

      it 'is linked from the nav on every page' do
        %w[index.html sample.html about.html 404.html].each do |name|
          nav = File.read("blog/public/#{name}")[%r{<nav class="site-nav">.*?</nav>}m]
          expect(nav).to include('<a href="/about.html">About</a>')
        end
      end

      it 'is in the sitemap but not the index listing or the feed' do
        expect(File.read('blog/public/sitemap.xml')).to include('<loc>https://example.com/about.html</loc>')
        expect(File.read('blog/public/index.html')[%r{<main>.*?</main>}m]).not_to include('about.html')
        expect(File.read('blog/public/feed.xml')).not_to include('about.html')
      end

      it 'is rebuilt by the watcher when views/about.md changes' do
        File.write('blog/views/about.md', "# About me\n\nSomething new about the author of this blog.\n")
        command.build('views/about.md')

        page = File.read('blog/public/about.html')
        expect(page).to include('<title>About me</title>')
        expect(page).to include('Something new about the author of this blog.')
      end

      it 'is removed, along with its sitemap entry, when views/about.md is deleted' do
        File.delete('blog/views/about.md')
        command.build('views/about.md')

        expect(File.exist?('blog/public/about.html')).to be false
        expect(File.read('blog/public/sitemap.xml')).not_to include('about.html')
      end
    end

    context 'post categories' do
      let(:build_config) { Parrot::Config.new(File.join(Dir.pwd, 'blog'), Logger.new(File::NULL)) }
      let(:command) { Parrot::Commands::BuildCommand.new([], build_config) }

      def write_post(name, title, date, category = nil)
        header = "title: #{title}\ndate: #{date}\n"
        header << "category: #{category}\n" if category
        File.write("blog/views/posts/#{name}.md", "<!--\n#{header}-->\n\n# #{title}\n\nBody text.\n")
      end

      def main_of(file)
        File.read("blog/public/#{file}")[%r{<main>.*?</main>}m]
      end

      before do
        write_post('ruby-old', 'Old Ruby', '01/01/2024', 'Ruby')
        write_post('ruby-new', 'New Ruby', '01/01/2025', 'Ruby')
        write_post('web', 'Web things', '01/06/2025', 'Web Dev')
      end

      it 'lists only that category\'s posts, newest first, under its name' do
        command.run
        main = main_of('category-ruby.html')

        expect(main).to include('<h3>Ruby</h3>')
        expect(main).not_to include('web.html')
        expect(main).not_to include('sample.html')
        expect(main.index('ruby-new.html')).to be < main.index('ruby-old.html')
        expect(File.read('blog/public/category-ruby.html')).to include('<title>Ruby posts</title>')
      end

      it 'names pages after the slugified category' do
        command.run
        expect(File.exist?('blog/public/category-web-dev.html')).to be true
      end

      it 'paginates a category past per_page, with a pager between its pages' do
        File.write('blog/config.yaml', "post_listing:\n  per_page: 1\n")
        command.run

        page1 = main_of('category-ruby.html')
        page2 = main_of('category-ruby_2.html')
        expect(page1).to include('ruby-new.html')
        expect(page1).to include('<a href="category-ruby_2.html">Older posts →</a>')
        expect(page2).to include('ruby-old.html')
        expect(page2).to include('<a href="category-ruby.html">← Newer posts</a>')
        expect(page2).to include('<h3>Ruby</h3>')
        expect(File.exist?('blog/public/category-ruby_3.html')).to be false
      end

      it 'lists every category with its post count on categories.html' do
        command.run
        main = main_of('categories.html')

        expect(main).to include('<a href="category-guides.html">Guides</a> (2)')
        expect(main).to include('<a href="category-ruby.html">Ruby</a> (2)')
        expect(main).to include('<a href="category-web-dev.html">Web Dev</a> (1)')
      end

      it 'still writes categories.html when no post has a category' do
        Dir['blog/views/posts/*.md'].each { |path| File.write(path, File.read(path).gsub(/^category:.*\n/, '')) }
        command.run

        expect(main_of('categories.html')).to include('No categories yet.')
        expect(Dir['blog/public/category-*.html']).to be_empty
      end

      it 'puts the date and a category link right after the post title' do
        command.run
        expect(main_of('ruby-new.html')).to include(
          '<h1>New Ruby</h1>' \
          "\n" \
          '<p class="post-meta"><time datetime="2025-01-01">01/01/2025</time> · ' \
          '<a class="category-tag" href="category-ruby.html">Ruby</a></p>'
        )
      end

      it 'shows just the date for a post without a category, and nothing without either' do
        write_post('plain', 'Plain', '01/02/2025')
        File.write('blog/views/posts/bare.md', "# Bare\n\nBody text.\n")
        command.run

        expect(main_of('plain.html')).to include('<p class="post-meta"><time datetime="2025-02-01">01/02/2025</time></p>')
        expect(main_of('bare.html')).not_to include('post-meta')
      end

      it 'replaces an old _{post_date}_ line instead of showing the date twice' do
        File.write('blog/views/posts/story.md',
                   "<!--\ntitle: A story\ndate: 08/09/2026\ncategory: Fiction\n-->\n\n# A story\n\n_{post_date}_\n\nBody.\n")
        command.run

        # the header comment is copied into <main> as-is, so leave it out
        main = main_of('story.html').gsub(/<!--.*?-->/m, '')
        expect(main.scan('08/09/2026').length).to eq(1)
        expect(main).to include('class="category-tag" href="category-fiction.html"')
      end

      it 'shows a category tag in the index listing by default' do
        command.run
        expect(main_of('index.html')).to include('<a href="category-ruby.html" class="category-tag">Ruby</a>')
      end

      it 'leaves the tag out when list_format drops {post_category_tag}' do
        File.write('blog/config.yaml', "post_listing:\n  list_format: \"[{post_title}]({post_link})\"\n")
        command.run
        expect(main_of('index.html')).not_to include('category-tag')
        expect(main_of('category-ruby.html')).not_to include('category-tag')
      end

      it 'lists categories.html and every category page in the sitemap' do
        File.write('blog/config.yaml', "post_listing:\n  per_page: 1\n")
        command.run

        sitemap = File.read('blog/public/sitemap.xml')
        expect(sitemap).to include('<loc>https://example.com/categories.html</loc>')
        expect(sitemap).to include("<loc>https://example.com/category-ruby.html</loc>\n    <lastmod>2025-01-01</lastmod>")
        expect(sitemap).to include('<loc>https://example.com/category-ruby_2.html</loc>')
      end

      it 'removes a category\'s pages once the watcher sees its last post move away' do
        command.run
        write_post('web', 'Web things', '01/06/2025', 'Ruby')
        command.build('views/posts/web.md')

        expect(File.exist?('blog/public/category-web-dev.html')).to be false
        expect(main_of('category-ruby.html')).to include('web.html')
        expect(main_of('categories.html')).not_to include('Web Dev')
      end

      it 'shares one page between names that slugify the same' do
        write_post('cpp', 'C plus plus', '01/03/2025', 'Web-Dev')
        command.run
        main = main_of('category-web-dev.html')

        expect(main).to include('web.html')
        expect(main).to include('cpp.html')
      end

      it 'fails the build when a post is named like a category page' do
        File.write('blog/views/posts/category-ruby.md', "# Clash\n")
        expect { command.run }.to raise_error(%r{Reserved post filename: views/posts/category-ruby\.md})
      end

      it 'builds a post named category-<something> when no such category exists' do
        File.write('blog/views/posts/category-theory.md', "# Category theory\n")
        expect { command.run }.not_to raise_error
        expect(File.exist?('blog/public/category-theory.html')).to be true
      end
    end

    context 'reserved post filenames' do
      let(:build_config) { Parrot::Config.new(File.join(Dir.pwd, 'blog'), Logger.new(File::NULL)) }
      let(:command) { Parrot::Commands::BuildCommand.new([], build_config) }

      %w[about.md 404.md index.md index3.md About.md now.md post.md posts.md note.md notes.md categories.md category.md].each do |name|
        it "fails the build on views/posts/#{name} before writing anything" do
          command.run
          File.write("blog/views/posts/#{name}", "# Clash\n")

          expect { command.run }.to raise_error(%r{Reserved post filename: views/posts/#{Regexp.escape(name)}})
          expect(File.exist?('blog/public/index.html')).to be true
        end
      end

      it 'fails the watcher rebuild when such a post appears' do
        command.run
        File.write('blog/views/posts/about.md', "# Clash\n")

        expect { command.build('views/posts/about.md') }.to raise_error(/Reserved post filename/)
        expect(File.read('blog/public/about.html')).to include('<title>About</title>')
      end

      it 'builds posts whose names only contain a reserved word' do
        File.write('blog/views/posts/about-me.md', "# About me\n")
        expect { command.run }.not_to raise_error
        expect(File.exist?('blog/public/about-me.html')).to be true
      end
    end

    context 'search' do
      let(:build_config) { Parrot::Config.new(File.join(Dir.pwd, 'blog'), Logger.new(File::NULL)) }
      let(:command) { Parrot::Commands::BuildCommand.new([], build_config) }
      let(:pages) { %w[index.html about_parrot.html sample.html categories.html category-guides.html 404.html about.html] }

      # Runs the built search.js under node with a stub DOM and returns
      # ParrotSearch.search's result for each query.
      def search_in_node(*queries)
        script = <<~JS
          global.window = {};
          global.document = {
            readyState: 'complete',
            querySelector: function () { return null; },
            querySelectorAll: function () { return []; },
            addEventListener: function () {}
          };
          eval(require('fs').readFileSync(process.argv[1], 'utf8'));
          console.log(JSON.stringify(JSON.parse(process.argv[2]).map(window.ParrotSearch.search)));
        JS
        output, status = Open3.capture2('node', '-e', script, 'blog/public/search.js', JSON.generate(queries))
        raise 'node failed' unless status.success?

        JSON.parse(output)
      end

      it 'is on for a new blog: builds search.js with every post and loads it on every page' do
        command.run

        script = File.read('blog/public/search.js')
        expect(script).to include('"title":"About Parrot","url":"about_parrot.html"')
        expect(script).to include('"url":"sample.html"')
        expect(script).not_to include('__PARROT_SEARCH_INDEX__')

        pages.each do |name|
          html = File.read("blog/public/#{name}")
          expect(html).to include('<script src="search.js" defer>')
          expect(html).to include('<div class="search" hidden')
          expect(html).to include('class="search-input" type="search" placeholder="Search posts"')
        end
        expect(File.read('blog/public/app.css')).to include('.search-suggestions{')
      end

      it 'puts the search box right after the header nav' do
        command.run
        html = Nokogiri::HTML(File.read('blog/public/index.html'))
        expect(html.at('header.site-header nav.site-nav').next_element['class']).to eq('search')
      end

      it 'stays off for an existing blog whose config.yaml has no search section' do
        File.write('blog/config.yaml', "post_listing:\n  list_title: \"Posts\"\n")
        command.run

        expect(File.exist?('blog/public/search.js')).to be false
        pages.each { |name| expect(File.read("blog/public/#{name}")).not_to include('search.js') }
        expect(File.read('blog/public/app.css')).not_to include('.search-suggestions')
      end

      it 'stays off when there is no config.yaml' do
        File.delete('blog/config.yaml')
        command.run

        expect(File.exist?('blog/public/search.js')).to be false
        expect(File.read('blog/public/index.html')).not_to include('class="search')
      end

      it 'stays off when the search section leaves out enabled' do
        File.write('blog/config.yaml', "search:\n  placeholder: \"Find a post\"\n")
        command.run
        expect(File.exist?('blog/public/search.js')).to be false
        expect(File.read('blog/public/index.html')).not_to include('class="search')
      end

      it 'fills an empty <div class="search"> the layout places itself, instead of adding one after the nav' do
        layout = 'blog/views/layout.html.erb'
        File.write(layout, File.read(layout).sub('<main>', '<div class="search"></div>\n  <main>'))
        command.run

        html = Nokogiri::HTML(File.read('blog/public/index.html'))
        expect(html.css('div.search').length).to eq(1)
        expect(html.at('div.search').next_element.name).to eq('main')
        expect(html.at('div.search .search-input')).not_to be_nil
      end

      it 'drops the layout\'s <div class="search"> when search is off' do
        layout = 'blog/views/layout.html.erb'
        File.write(layout, File.read(layout).sub('<main>', '<div class="search"></div>\n  <main>'))
        File.write('blog/config.yaml', "search:\n  enabled: false\n")
        command.run

        expect(File.read('blog/public/index.html')).not_to include('class="search')
      end

      it 'keeps a byte-order mark from the compiled CSS at the very start of app.css' do
        File.write('blog/css/app.scss', ":root { --quote: \"“\"; }\n")
        command.run

        css = File.read('blog/public/app.css', encoding: 'UTF-8')
        expect(css).to start_with("\uFEFF.search{")
        expect(css.count("\uFEFF")).to eq(1)
      end

      it 'uses config.yaml search.placeholder' do
        File.write('blog/config.yaml', "search:\n  enabled: true\n  placeholder: \"Find a post\"\n")
        command.run
        expect(File.read('blog/public/index.html')).to include('placeholder="Find a post"')
      end

      it 'leaves skipped drafts out of the index' do
        File.write('blog/views/posts/story.md', "<!--\ntitle: Secret story\ndraft: true\n-->\n\n# story\n")
        command.run
        expect(File.read('blog/public/search.js')).not_to include('story.html')
      end

      it 'builds no search.js and no search UI when search.enabled is false' do
        File.write('blog/config.yaml', "search:\n  enabled: false\n")
        command.run

        expect(File.exist?('blog/public/search.js')).to be false
        pages.each do |name|
          html = File.read("blog/public/#{name}")
          expect(html).not_to include('search.js')
          expect(html).not_to include('class="search')
        end
        expect(File.read('blog/public/app.css')).not_to include('.search-suggestions')
        expect(File.read('blog/public/index.html')).to include('about_parrot.html')
      end

      it 'is switched off and back on by the watcher when config.yaml changes' do
        command.run
        File.write('blog/config.yaml', "search:\n  enabled: false\n")
        command.build('config.yaml')

        expect(File.exist?('blog/public/search.js')).to be false
        pages.each { |name| expect(File.read("blog/public/#{name}")).not_to include('search.js') }

        File.write('blog/config.yaml', "search:\n  enabled: true\n")
        command.build('config.yaml')
        expect(File.exist?('blog/public/search.js')).to be true
        expect(File.read('blog/public/404.html')).to include('<script src="search.js" defer>')
      end

      it 'reindexes when the watcher rebuilds a changed post' do
        command.run
        post = 'blog/views/posts/sample.md'
        File.write(post, File.read(post).sub('title: Your second post', 'title: Renamed post'))
        command.build('views/posts/sample.md')

        expect(File.read('blog/public/search.js')).to include('"title":"Renamed post"')
      end

      context 'in the browser', if: system('node --version', out: File::NULL, err: File::NULL) do
        before do
          File.write('blog/views/posts/ruby.md', "<!--\ntitle: Ruby Tips\ndate: 01/10/2026\ntags: ruby, testing\n-->\n\n# Ruby\n")
          File.write('blog/views/posts/rust.md', "<!--\ntitle: Rust notes\ndate: 02/10/2026\ncategory: Guides\n-->\n\n# Rust\n")
          command.run
        end

        it 'matches prefixes of titles, tags and categories, newest first' do
          ru, test, guide = search_in_node('ru', 'test', 'guide')
          expect(ru.map { |post| post['url'] }).to eq(%w[rust.html ruby.html])
          expect(test).to eq([{ 'title' => 'Ruby Tips', 'url' => 'ruby.html' }])
          expect(guide.map { |post| post['url'] }).to include('rust.html', 'sample.html')
        end

        it 'is case-insensitive and lists each post once' do
          upper, both = search_in_node('RUBY', 'ruby ru')
          expect(upper.map { |post| post['url'] }).to eq(%w[ruby.html])
          expect(both.map { |post| post['url'] }).to eq(%w[ruby.html])
        end

        it 'requires every word of the query to match' do
          expect(search_in_node('rust ruby')).to eq([[]])
        end

        it 'returns nothing for empty, blank or unmatched queries' do
          expect(search_in_node('', '   ', '!!', 'python')).to eq([[], [], [], []])
        end
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
