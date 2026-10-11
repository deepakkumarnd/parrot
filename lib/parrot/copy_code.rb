require 'fileutils'
require 'nokogiri'

module Parrot
  # Copy buttons on code blocks, mixed into `build`. Expects the including
  # class to provide app_root, build_path and config.
  module CopyCode
    # Browser-side copy buttons and their default styles, shipped by the gem
    # into every build. The layout loads the script on every page; it only
    # adds buttons where there's a code block.
    COPY_CODE_SCRIPT = File.expand_path('assets/copy_code.js', __dir__)
    COPY_CODE_STYLESHEET = File.expand_path('assets/copy_code.css', __dir__)

    # The button's icon, from the blog's images/ so it can be replaced.
    # Blogs created before copy buttons existed don't have one, so the
    # skeleton's copy is shipped instead.
    COPY_ICON = File.join('images', 'copy-icon.svg')
    DEFAULT_COPY_ICON = File.expand_path("../../skel/#{COPY_ICON}", __dir__)

    # Adds <script src="copy-code.js"> to a page whose layout doesn't load
    # it already, as layouts from before copy buttons existed don't.
    def inject_copy_code(html)
      return html if html.at('script[src="copy-code.js"]')

      script = Nokogiri::XML::Node.new('script', html)
      script['src'] = 'copy-code.js'
      script['defer'] = 'defer'
      script.content = '' # Needed to close the tag properly
      (html.at('head') || html.at('body') || html).add_child(script)
      html
    end

    # Copies the copy-button script into public/copy-code.js and its icon
    # into public/images/copy-icon.svg.
    def build_copy_code
      output = File.join(build_path, 'copy-code.js')
      FileUtils.cp(COPY_CODE_SCRIPT, output)
      config.logger.info "Copied copy-code.js to #{build_path}"

      icon = File.join(app_root, COPY_ICON)
      icon = DEFAULT_COPY_ICON unless File.exist?(icon)
      FileUtils.mkdir_p(File.join(build_path, 'images'))
      FileUtils.cp(icon, File.join(build_path, COPY_ICON))
      config.logger.info "Copied #{COPY_ICON} to #{build_path}"
    end

    private

    # The copy button's and toast's default styles, put ahead of the user's
    # own CSS so they can override them.
    def copy_code_css
      File.read(COPY_CODE_STYLESHEET)
    end
  end
end
