# -*- encoding: utf-8 -*-

require 'tilt'
require 'tilt/template'


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
