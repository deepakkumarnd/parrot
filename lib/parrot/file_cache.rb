require 'digest'
require 'singleton'

class FileCache

  include Singleton

  attr_accessor :cache

  def initialize
    @cache = {}
  end

  def fetch(path)
    cache[path]
  end

  def set(path)
    cache[path] = Digest::SHA256.hexdigest(File.read(path))
  end

  def changed?(path)
    return true unless cache.has_key?(path)
    data = File.read(path)
    !(cache[path] == Digest::SHA256.hexdigest(data))
  end
end