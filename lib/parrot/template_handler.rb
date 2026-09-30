module Parrot
  class TemplateHandler
    HANDLERS = {
      html: [:slim],
      css: [:scss],
      js: [:coffee]
    }.freeze

    def initialize(options = {})
      @root = options[:root]
      @path = options[:path]
      @handler = HANDLERS[options[:handle]]
    end

    def handler_engines(type)
      HANDLERS[type]
    end
  end
end
