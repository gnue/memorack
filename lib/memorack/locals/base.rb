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

		define_key :subdirs do |key|
			unless @subdirs
				@subdirs = []

				path_info = self[:path_info]
				break unless path_info

				href = self[:site][:url].to_s

				File.dirname(path_info).split('/').each { |dir|
					next if dir == '.'
					href = File.join(href, dir)
					next if dir.empty?

					@subdirs << {name: dir, href: href}
				}
			end

			@subdirs
		end

		define_key :nav do |key|
			unless @nav
				@nav = []
				@nav << {name: self[:title], href: File.join(self[:site][:url].to_s, '')}
				@nav += self[:subdirs] if self[:subdirs]
				@nav << {name: self[:page][:name]} if self[:page][:name]
				@nav.last[:last?] = true
			end

			@nav
		end

	end

end
