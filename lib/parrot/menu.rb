require 'fileutils'
require 'nokogiri'
require_relative 'skeleton'

module Parrot
  # The header's dropdown menu and the pages it lists, mixed into `build`.
  # Every views/menu/<name>.md is built to <name>.html and linked from the
  # dropdown; config.yaml's `menu` section names the dropdown and picks
  # which pages it lists, in which order. Expects the including class to
  # provide app_root, build_path, config, posts_config and the page helpers
  # (markdown, update_internal_links, summarize, apply_page_meta, …).
  module Menu
    MENU_DIR = File.join('views', 'menu')

    # The dropdown's styles, from the blog so they can be edited. Blogs
    # created before the menu existed don't have them, so the skeleton's
    # copy is used instead.
    MENU_STYLESHEET = File.join('css', '_menu.scss')

    # The dropdown's script, shipped by the gem at the start of app.js.
    MENU_SCRIPT = File.expand_path('assets/menu.js', __dir__)

    # Names a menu page can't take, since they'd build to the same file as a
    # page Parrot generates itself (index pages, 404.html, categories.html,
    # category-<slug>.html).
    RESERVED_MENU_PAGE_NAMES = /\A(?:index\d*|404|categories|category-.*)\z/i

    # Fills the layout's <div class="menu"> placeholder with the dropdown:
    #   <details class="menu"><summary>Menu</summary>
    #     <ul class="menu-items"><li><a href="/about.html">About me</a></li>…</ul>
    #   </details>
    # The placeholder is removed when there are no menu pages. Layouts
    # without one (from before the menu existed) are left as they are.
    def inject_menu(html)
      placeholder = html.at('div.menu')
      return html unless placeholder

      items = menu_items
      if items.empty?
        placeholder.remove
        return html
      end

      details = Nokogiri::XML::Node.new('details', html)
      details['class'] = 'menu'

      summary = Nokogiri::XML::Node.new('summary', html)
      summary.content = menu_settings['label'] || DEFAULT_MENU_LABEL
      details.add_child(summary)

      list = Nokogiri::XML::Node.new('ul', html)
      list['class'] = 'menu-items'
      items.each do |item|
        link = Nokogiri::XML::Node.new('a', html)
        link['href'] = "/#{item[:name]}.html"
        link.content = item[:title]

        entry = Nokogiri::XML::Node.new('li', html)
        entry.add_child(link)
        list.add_child(entry)
      end
      details.add_child(list)

      placeholder.replace(details)
      html
    end

    # Builds every menu page to public/<name>.html. A page config.yaml's
    # menu.pages leaves out isn't built, and a copy left by an earlier build
    # is removed.
    def build_menu_pages
      pages = menu_page_paths
      pages.each { |name, source| build_menu_page(name, source) }

      (all_menu_page_paths.keys - pages.keys).each do |name|
        next if File.exist?(File.join(app_root, 'views', 'posts', "#{name}.md"))

        remove_menu_page(name)
      end
    end

    # Builds one menu page. It takes the same optional `<!-- key: value -->`
    # header as a post (title, description, lang) but isn't one: it stays
    # out of the index listing and the feed, and is listed in the sitemap.
    def build_menu_page(name, source)
      meta = post_metadata(source)
      layout = Tilt.new("#{app_root}/views/layout.html.erb")
      body = markdown(source).render

      html = update_internal_links(layout.render { body })
      copy_image_assets(html)
      inject_menu(html)
      inject_search(html)
      inject_copy_code(html)

      meta['title'] ||= menu_page_title(name, source)
      meta['description'] ||= summarize(body)
      output_name = "#{name}.html"
      apply_page_meta(html, output_name, meta, kind: name == 'about' ? :about : :page)

      output = File.join(build_path, output_name)
      File.write(output, html)
      config.logger.info "Built #{output}"
    end

    def remove_menu_page(name)
      output = File.join(build_path, "#{name}.html")
      return unless File.exist?(output)

      File.delete(output)
      config.logger.info "Removed #{output}"
    end

    # The menu pages this build writes, as { name => source path }: the ones
    # config.yaml's menu.pages lists, in its order, or every menu page by
    # name when it lists none.
    def menu_page_paths
      pages = all_menu_page_paths
      order = menu_settings['pages']
      return pages unless order.is_a?(Array)

      order.map(&:to_s).each_with_object({}) do |name, selected|
        if pages.key?(name)
          selected[name] = pages[name]
        else
          config.logger.warn "menu.pages lists #{name.inspect}, but there's no #{MENU_DIR}/#{name}.md"
        end
      end
    end

    private

    # Fails the build when a menu page would overwrite (or be overwritten by)
    # a page Parrot generates itself.
    def check_menu_page_names!
      clashes = menu_page_paths.keys.grep(RESERVED_MENU_PAGE_NAMES)
      return if clashes.empty?

      names = clashes.map { |name| "#{MENU_DIR}/#{name}.md" }.join(', ')
      raise "Reserved menu page filename: #{names}. index*, 404, categories and category-* can't be used " \
            'as menu page names; rename the page to build.'
    end

    # The dropdown's entries, in menu order.
    def menu_items
      @menu_items ||= menu_page_paths.map do |name, source|
        { name: name, title: menu_page_title(name, source) }
      end
    end

    # A menu page's title, in the dropdown and its <title>: its header
    # `title`, its first Markdown heading of any level ("### About me"), or
    # else its name in title case ("my-projects" -> "My Projects").
    def menu_page_title(name, source)
      post_metadata(source)['title'] ||
        File.read(source)[/^\#{1,6}[ \t]+(.+?)[ \t#]*$/, 1] ||
        name.tr('-_', ' ').split.map(&:capitalize).join(' ')
    end

    # Every menu page there is, as { name => source path }, sorted by name.
    def all_menu_page_paths
      Dir[File.join(app_root, MENU_DIR, '*.md')].to_h { |path| [File.basename(path, '.md'), path] }
    end

    # The `menu` section of config.yaml, or {}.
    def menu_settings
      settings = posts_config['menu']
      settings.is_a?(Hash) ? settings : {}
    end
  end
end
