require 'json'

module Parrot
  # The trie behind the client-side search box. Every keyword token (from a
  # post's title, tags and category) is inserted one character per level;
  # the node a token ends on lists, under "$", the ids of the posts it came
  # from. Post ids index into #posts, which holds just what a suggestion
  # needs — title and url — in the order posts were added (newest first), so
  # a lower id is a newer post. Serialized into public/search.js, where
  # lib/parrot/assets/search.js walks it for prefix matches.
  class SearchIndex
    # Never a key character: tokens are only letters, marks and digits.
    POSTS_KEY = '$'.freeze

    attr_reader :posts, :trie

    # "Ruby's C-API, 2nd ed." -> ["ruby", "s", "c", "api", "2nd", "ed"].
    # Combining marks (\p{M}) are kept, not stripped, so Malayalam, Hindi or
    # Tamil words keep their vowel signs. search.js tokenizes queries the
    # same way.
    def self.tokenize(text)
      text.to_s.downcase.scan(/[\p{L}\p{M}\p{N}]+/)
    end

    def initialize
      @posts = []
      @trie = {}
    end

    # Adds one post, indexed under every token of its title and keywords.
    def add(title:, url:, keywords: [])
      id = @posts.length
      @posts << { 'title' => title, 'url' => url }

      [title, *keywords].flat_map { |text| self.class.tokenize(text) }.uniq.each do |token|
        node = token.each_char.reduce(@trie) { |current, char| current[char] ||= {} }
        ids = node[POSTS_KEY] ||= []
        ids << id unless ids.include?(id)
      end
    end

    # The posts with a token starting with `prefix`, each once, newest first.
    # Mirrors search.js's lookup for a single-word query.
    def lookup(prefix)
      token = self.class.tokenize(prefix).first
      return [] unless token

      node = token.each_char.reduce(@trie) { |current, char| current && current[char] }
      return [] unless node

      collect_ids(node).sort.map { |id| @posts[id] }
    end

    def to_h
      { 'posts' => @posts, 'trie' => @trie }
    end

    def to_json(*)
      JSON.generate(to_h)
    end

    private

    def collect_ids(node, ids = Set.new)
      node.each do |key, value|
        key == POSTS_KEY ? ids.merge(value) : collect_ids(value, ids)
      end
      ids
    end
  end
end
