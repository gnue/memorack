# -*- encoding: utf-8 -*-

require 'memorack/locals'
require 'memorack/locals/app'


module MemoRack

	class BaseLocals < Locals

		def initialize(app, hash = nil, ifnone = nil)
			super ifnone

			@app = app
			merge!(hash) if hash

			self[:app] = AppLocals[]
		end

		define_key :__menu__ do |key|
			@app.render_menu
		end
	end

end
