require 'fileutils'
require 'nokogiri'
require_relative 'skeleton'

module Parrot
  # Copy buttons on code blocks, mixed into `build`. Expects the including
  # class to provide app_root, build_path and config.
  module CopyCode
    # Browser-side copy buttons, shipped by the gem into every build. The
    # layout loads the script on every page; it only adds buttons where
    # there's a code block.
    COPY_CODE_SCRIPT = File.expand_path('assets/copy_code.js', __dir__)

    # The button's styles and icon, from the blog so they can be edited.
    # Blogs created before copy buttons existed don't have them, so the
    # skeleton's copies are used instead.
    COPY_CODE_STYLESHEET = File.join('css', '_copy_code.scss')
    COPY_ICON = File.join('images', 'copy-icon.svg')

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

      icon = Skeleton.path(app_root, COPY_ICON)
      FileUtils.mkdir_p(File.join(build_path, 'images'))
      FileUtils.cp(icon, File.join(build_path, COPY_ICON))
      config.logger.info "Copied #{COPY_ICON} to #{build_path}"
    end
  end
end
