# -*- encoding: utf-8 -*-

require 'memorack/locals'
require 'memorack/locals/app'


module MemoRack

	class BaseLocals < Locals

		attr_reader :app

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

		define_key :topicpath do |key|
			unless @topicpath
				@topicpath = []
				@topicpath << {name: self[:title], href: File.join(self[:site][:url].to_s, '')}
				@topicpath += self[:subdirs] if self[:subdirs]
				@topicpath << {name: self[:page][:name]} if self[:page][:name]
				@topicpath.last[:last?] = true
			end

			@topicpath
		end

		define_key :pages do |key|
			unless @pages
				@pages = []

				@app.pages.each { |path_info, path|
					href = self[:site][:url].to_s
					href = File.join(href, path_info)
					href += @app.suffix unless @app.suffix.empty?

					if plugin = PageInfo[path]
						pageinfo = plugin.new(path, nil, {path_info: path_info})
						name = pageinfo[:title]
					end

					name ||= File.basename(path_info)

					@pages << {name: name, href: href}
				}
			end

			@pages
		end

	end

end
