# coding: utf-8

require 'rubygems'
require 'rack'
require 'sass'
require 'uri'

require 'tilt-mustache'
require 'mdmenu'


class MemoApp
	DEFAULT_APP_OPTIONS = {
		root:			'views/',
		themes_folder:	'themes/',
		theme:			'default',
		markdown:		'redcarpet',
		title:			'memo'
	}

	# テンプレートエンジンのオプション
	DEFAULT_TEMPLATE_OPTIONS = {
		tables:			true
	}

	DEFAULT_OPTIONS = DEFAULT_APP_OPTIONS.merge(DEFAULT_TEMPLATE_OPTIONS)

	def initialize(app, options={})
		options = DEFAULT_OPTIONS.merge(to_sym_keys(options))

		@themes_folders = [options[:themes_folder], File.expand_path('../themes/', __FILE__)]
		read_config(options[:theme], options)

		use_engine(options[:markdown])

		@app = app
		@options = options
		@root = options[:root]
		@title = options[:title]

		define_statics(@root, *@themes)

		# @options からテンプレートで使わないものを削除
		DEFAULT_APP_OPTIONS.each { |key, item| @options.delete(key) }
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
			content = render :scss, "#{path}.scss", {views: @themes, cache_location: './tmp/sass-cache'}
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

	# テーマのパスを取得する
	def theme_path(theme)
		return nil unless theme

		@themes_folders.each { |folder|
			path = theme && File.join(folder, theme)
			return path if File.exists?(path) && FileTest::directory?(path)
		}

		nil
	end

	# 設定ファイルを読込む
	def read_config(theme, options = {})
		@themes ||= []
		options_chain = []

		begin
			require 'json'

			while theme
				dir = theme_path(theme)
				break unless dir
				break if @themes.member?(dir)

				# テーマ・チェインに追加
				@themes << File.join(dir, '')

				# config の読込み
				path = File.join(dir, 'config.json')
				break unless File.readable?(path)

				data = File.read(path)
				options_chain << to_sym_keys(JSON.parse(data))

				theme = options_chain.last[:theme]
			end
		rescue
		end

		# オプションをマージ
		options_chain.reverse.each { |opts| options.merge!(opts) }
		options
	end

	# 静的ファイルの参照先を定義する
	def define_statics(*args)
		@statics = [] unless @statics

		@statics |= args.collect { |root| Rack::File.new(root) }
	end

	# 次のアプリにパスする
	def pass(env, apps = @statics + [@app])
		apps.each { |app|
			next unless app

			result =  app.call(env)
			return result unless result.first == 404
		}

		[404, {'Content-Type' => 'text/plain'}, ['File not found: ', env['PATH_INFO']]]
	end

	# テンプレートエンジンで render する
	def render(engine, template, options = {}, locals = {})
		options = {views: @root}.merge(options)

		if options[:views].kind_of?(Array)
			err = nil

			options[:views].each { |views|
				options[:views] = views

				begin
					return render(engine, template, options, locals)
				rescue Errno::ENOENT => e
					err = e
				end
			}

			raise err
		end

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
			options = @options.merge(options)

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

			render :mustache, 'index.html', {views: @themes}, locals
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
			render :markdown, 'index.md', {views: @themes}
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
