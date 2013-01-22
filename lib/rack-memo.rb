# coding: utf-8

require 'rubygems'
require 'rack'
require 'sass'
require 'uri'

require 'tilt-mustache'
require 'mdmenu'


class MemoApp
	DEFAULT_OPTIONS = {root: 'views/', themes_folder: 'themes/', title: 'memo'}

	def initialize(app, options={})
		options = DEFAULT_OPTIONS.merge(to_sym_keys(options))
		options.merge!(read_config(options[:config])) if options[:config]

		use_engine(options[:markdown])

		@options = options
		@root = options[:root]
		@themes_folder = options[:themes_folder]
		@title = options[:title]
		@theme = File.join(@themes_folder, options[:theme], '')
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
			content = render :scss, "#{path}.scss", {views: @theme, cache_location: './tmp/sass-cache'}
		else
			return pass(env) unless ext && Tilt.registered?(ext)
			content = render_with_mustache path.to_sym, ext
		end

		return pass(env) unless content

		[200, {'Content-Type' => content_type}, [content.to_s]]
	end


	# テンプレートエンジンを使用できるようにする
	def use_engine(engine)
		require engine if engine

		# Tilt で Redcarpet 2.x を使うためのおまじない
		Object.send(:remove_const, :RedcarpetCompat) if defined?(RedcarpetCompat) == 'constant'
	end

	# 設定ファイルを読込む
	def read_config(path)
		begin
			require 'json'

			data = File.read(path)
			to_sym_keys(JSON.parse(data))
		rescue
			{}
		end
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
		options = {views: @root}.merge(options)

		fname = template.kind_of?(String) ? template : "#{template}.#{engine}"
		path = File.join(options[:views], fname)

		engine = Tilt.new(File.join(File.dirname(path), ".#{engine}"), options) {
			method = MemoApp.template_method(template)

			if method && respond_to?(method)
				data = send(method)
			else
				data = File.binread(path)
				data.force_encoding('UTF-8')
			end

			data
		}
		engine.render(options, locals)
	end

	# レイアウトに mustache を適用してテンプレートエンジンでレンダリングする
	def render_with_mustache(template, engine = :markdown, options = {}, locals = {})
		begin
			options = {tables: true}.merge(options)

			menu = render :markdown, :menu, options
			content = render engine, template, options
			fname = template.to_s.force_encoding('UTF-8')

			locals = locals.dup

			locals[:menu]			||= menu.force_encoding('UTF-8')
			locals[:content]		||= content.force_encoding('UTF-8')
			locals[:title]			||= @title
			locals[:page]			||= {}

			locals[:page][:title]	||= locals[:title] if template == :index
			locals[:page][:title]	||= [File.basename(fname), locals[:title]].join(' | ')

			render :mustache, 'index.html', {views: @theme}, locals
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

	# テンプレート名
	def self.template_method(name)
		name.kind_of?(Symbol) && "template_#{name}".to_sym
	end

	# テンプレートを作成する
	def self.template(name, &block)
		define_method(self.template_method(name), &block)
	end

	#### テンプレート

	# インデックスを作成
	template :index do
		begin
			render :markdown, 'index.md', {views: @theme}
		rescue
			''
		end
	end

	# メニューを作成
	template :menu do
		mdmenu = MdMenu.new({prefix: '/', uri_escape: true})
		Dir.chdir(@root) { |path| mdmenu.collection('.') }
		mdmenu.generate(StringIO.new).string
	end

end
