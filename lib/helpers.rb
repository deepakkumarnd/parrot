module Parrot
  module Helpers
    module_function

    def testing?
      ENV['PARROT_TESTING'] == 'true'
    end

    # "My First Post!" -> "my-first-post". Used for post filenames and for
    # category page names, so it only ever yields [a-z0-9-].
    def slugify(text)
      text.downcase
          .gsub(/[^a-z0-9\s-]/, '')
          .strip
          .gsub(/\s+/, '-')
          .gsub(/-+/, '-')
    end
  end
end
