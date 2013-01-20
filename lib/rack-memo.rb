# coding: utf-8

require 'rubygems'
require 'rack'
require 'sass'
require 'uri'

require 'sinatra-mustache'
require 'mdmenu'


class MemoApp
	class Templates
		# インデックスを作成
		def self.index(options = {}, locals = {})
			''
		end

		# メニューを作成
		def self.menu(options = {}, locals = {})
			mdmenu = MdMenu.new({prefix: '/', uri_escape: true})
			Dir.chdir(options[:views]) { |path| mdmenu.collection('.') }
			mdmenu.generate(StringIO.new).string
		end
	end

	# テンプレート
	def self.template(name, &block)
		Templates.define_method(name, &block)
	end

	def initialize(app, options={})
		options = to_sym_keys(options)

		require options[:markdown] if options[:markdown]

		@options = options
		@root = options[:root]
		@title = options[:title]
		@theme = options[:theme]
		@apps = @statics = [Rack::File.new(@root), Rack::File.new(@theme)]
		@apps << app if app
	end

	def call(env)
		content_type = 'text/html'

		path_info = URI.unescape(env['PATH_INFO'])
		path, ext = split_extname(path_info)

		case path_info
		when '/'
			content = render_with_mustache :index, :markdown
		when /\.css$/
			result = pass(env, @statics)
			return result unless result.first == 404

			content_type = 'text/css'
			content = render :scss, path.to_sym, {views: @theme}
		else
			return pass(env) unless ext && Tilt.registered?(ext)
			content = render_with_mustache path.to_sym, ext
		end

		return pass(env) unless content

		[200, {'Content-Type' => content_type}, [content.to_s]]
	end


	# 次のアプリにパスする
	def pass(env, apps = @apps)
		apps.each { |app|
			result =  app.call(env)
			return result unless result.first == 404
		}

		[404, {'Content-Type' => 'text/plain'}, ['File not found: ', env['PATH_INFO']]]
	end

	# テンプレートエンジンで render する
	def render(engine, template, options = {}, locals = {})
		options[:views] ||= @root
		path = File.join(options[:views], "#{template}.#{engine}")

		begin
			engine = Tilt.new(path) {
				if template.kind_of?(Symbol) && Templates.respond_to?(template)
					data = Templates.send(template, options, locals)
				else
					data = File.binread(path)
					data.force_encoding('UTF-8')
				end
			}
			engine.render(options, locals)
		rescue => e
			e.to_s
		end
	end

	# レイアウトに mustache を適用してテンプレートエンジンでレンダリングする
	def render_with_mustache(template, engine = :markdown, options = {}, locals = {})
		begin
			menu = render :markdown, :menu, options
			options[:tables] = true
			content = render engine, template, options

			locals[:menu]			||= menu.force_encoding('UTF-8')
			locals[:content]		||= content.force_encoding('UTF-8')
			locals[:title]			||= @title || 'memo'
			locals[:page]			||= {}

			locals[:page][:title]	||= locals[:title] if template == :index
			locals[:page][:title]	||= [File.basename(template.to_s), locals[:title]].join(' | ')

			render :mustache, :layout, {views: @theme}, locals
		rescue => e
			e.to_s
		end
	end

	# 拡張子を取出す
	def split_extname(path)
		return [$1, $2] if /^(.+)\.([^.]+)/ =~ path

		[path]
	end

	# キーをシンボルに変換する
	def to_sym_keys(hash)
		hash.inject({}) { |memo, entry|
			key, value = entry
			memo[key.to_sym] = value
			memo
		}
	end
end
