require 'digest'
require 'singleton'

class FileCache

  include Singleton

  attr_accessor :cache

  # Digest over the combined state of every tracked file. Recomputed on
  # every #set, so a single value tells you whether the cache as a whole
  # has moved.
  attr_reader :checksum

  def initialize
    @cache = {}
    @checksum = compute_checksum
  end

  def fetch(path)
    cache[path]
  end

  def set(path)
    digest = Digest::SHA256.hexdigest(File.read(path))
    cache[path] = digest
    @checksum = compute_checksum
    digest
  end

  def changed?(path)
    return true unless cache.has_key?(path)
    data = File.read(path)
    !(cache[path] == Digest::SHA256.hexdigest(data))
  end

  private

  # Hash the whole cache. Entries are sorted by path so the result depends
  # only on the contents, not on insertion order.
  def compute_checksum
    payload = cache.sort.map { |path, sha| "#{path}:#{sha}" }.join("\n")
    Digest::SHA256.hexdigest(payload)
  end
end
