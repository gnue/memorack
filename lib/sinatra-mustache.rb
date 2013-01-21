# coding: utf-8

require 'sinatra/base'
require 'tilt-mustache'


module Sinatra
  module Templates
    def mustache(template, options={}, locals={})
      render :mustache, template, options, locals
    end
  end
end
