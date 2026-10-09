require 'nokogiri'
require_relative 'search_index'

module Parrot
  module Search
    # The client-side search box, mixed into `build`. Expects the including
    # class to provide build_path, config, posts_config, sorted_posts_metadata
    # and PostHeader's post_tags / post_category.
    module Searchable
      # Browser-side search and the search box's default styles, shipped by
      # the gem into builds that turn search on.
      SEARCH_SCRIPT = File.expand_path('../assets/search.js', __dir__)
      SEARCH_STYLESHEET = File.expand_path('../assets/search.css', __dir__)

      # Adds the search box and <script src="search.js"> to a page when
      # config.yaml turns search on, hidden until search.js has wired it up.
      # A layout places the box itself with an empty <div class="search">;
      # otherwise it goes at the end of <header>, on its own row below the
      # nav (or at the top of <body>, for layouts without a header). With
      # search off, that placeholder is removed so it doesn't take up room.
      def inject_search(html)
        placeholder = html.at('div.search')
        unless search_enabled?
          placeholder&.remove
          return html
        end

        body = html.at('body')
        return html unless body

        container = placeholder || Nokogiri::XML::Node.new('div', html)
        container.children.each(&:remove)
        container['class'] = 'search'
        container['hidden'] = 'hidden'

        input = Nokogiri::XML::Node.new('input', html)
        input['class'] = 'search-input'
        input['type'] = 'search'
        input['placeholder'] = search_settings['placeholder'] || DEFAULT_SEARCH_PLACEHOLDER
        input['aria-label'] = 'Search posts'
        input['autocomplete'] = 'off'
        container.add_child(input)

        list = Nokogiri::XML::Node.new('ul', html)
        list['class'] = 'search-suggestions'
        list['id'] = 'search-suggestions'
        list['role'] = 'listbox'
        list['hidden'] = 'hidden'
        container.add_child(list)

        unless placeholder
          header = html.at('header')
          header ? header.add_child(container) : body.prepend_child(container)
        end

        script = Nokogiri::XML::Node.new('script', html)
        script['src'] = 'search.js'
        script['defer'] = 'defer'
        script.content = '' # Needed to close the tag properly
        (html.at('head') || body).add_child(script)
        html
      end

      # Writes public/search.js: the browser-side search from
      # lib/parrot/assets/search.js with a trie of every published post's
      # title, tags and category baked in, so searching never touches the
      # network. Removed instead when config.yaml turns search off.
      def build_search
        output = File.join(build_path, 'search.js')
        unless search_enabled?
          FileUtils.rm_f(output)
          return
        end

        index = SearchIndex.new
        sorted_posts_metadata.each do |meta|
          index.add(
            title: meta['title'] || File.basename(meta['__filename'], '.md'),
            url: meta['__filename'].sub('.md', '.html'),
            keywords: [*post_tags(meta), *post_category(meta)]
          )
        end

        script = File.read(SEARCH_SCRIPT)
                     .sub('/*__PARROT_SEARCH_INDEX__*/null') { index.to_json }
                     .sub('/*__PARROT_SEARCH_LIMIT__*/10') { SEARCH_SUGGESTION_LIMIT.to_s }
        File.write(output, script)
        config.logger.info "Built #{output}"
      end

      private

      # The search box's default styles, put ahead of the user's own CSS.
      def search_css
        File.read(SEARCH_STYLESHEET)
      end

      # The `search` section of config.yaml, or {}.
      def search_settings
        settings = posts_config['search']
        settings.is_a?(Hash) ? settings : {}
      end

      # Search is opt-in per blog: on only when config.yaml's `search`
      # section sets `enabled: true` (new blogs get that from the skeleton).
      # Blogs created before search existed have no such section, so their
      # builds stay as they were.
      def search_enabled?
        posts_config['search'].is_a?(Hash) && search_settings['enabled'] == true
      end
    end
  end
end
