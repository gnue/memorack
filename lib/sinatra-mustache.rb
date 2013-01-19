require 'sinatra/base'
require 'tilt/template'


module Sinatra
  module Templates
    def mustache(template, options={}, locals={})
      render :mustache, template, options, locals
    end
  end
end


module Tilt
  class MustacheTemplate < Template
    def self.engine_initialized?
      defined? ::Mustache
    end

    def initialize_engine
      require_template_library 'mustache'
    end

    def prepare
      @engine = Mustache.new
      @engine.template = data
      @output = nil
    end

    def evaluate(scope, locals, &block)
      @output ||= @engine.render(locals)
    end
  end

  register MustacheTemplate,    'mustache'
end
