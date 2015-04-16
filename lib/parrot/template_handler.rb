module Parrot
  class TemplateHandler
    Handlers = {
      html: [:slim],
      css: [:scss],
      js: [:coffee]
    }

    def initialize(options = {})
      @root = options[:root]
      @path = options[:path]
      @handler = Handlers[options[:handle]]
    end

    def handler_engines(type)
      Handlers[type]
    end
  end
end