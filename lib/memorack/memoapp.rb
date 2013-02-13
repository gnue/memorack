# coding: utf-8

require 'rubygems'
require 'rack'
require 'uri'

require 'memorack/tilt-mustache'
require 'memorack/mdmenu'

module MemoRack
	class MemoApp
		DEFAULT_APP_OPTIONS = {
			root:				'content/',
			themes_folder:		'themes/',
			tmpdir:				'tmp/',
			theme:				'default',
			markdown:			'redcarpet',
			formats:			['markdown'],
			css:				nil,
			directory_watcher:	false
		}

		# テンプレートエンジンのオプション
		DEFAULT_TEMPLATE_OPTIONS = {
			tables:			true
		}

		# テンプレートで使用するローカル変数の初期値
		DEFAULT_LOCALS = {
			title:				'memo'
		}

		DEFAULT_OPTIONS = DEFAULT_APP_OPTIONS.merge(DEFAULT_TEMPLATE_OPTIONS).merge(DEFAULT_LOCALS)

		def initialize(app, options={})
			options = DEFAULT_OPTIONS.merge(to_sym_keys(options))

			@themes_folders = [options[:themes_folder], File.expand_path('../themes/', __FILE__)]
			read_config(options[:theme], options)

			@app = app
			@options = options

			# DEFAULT_APP_OPTIONS に含まれるキーをすべてインスタンス変数に登録する
			DEFAULT_APP_OPTIONS.each { |key, item|
				instance_variable_set("@#{key}".to_sym, options[key])

				# @options からテンプレートで使わないものを削除
				@options.delete(key)
			}

			@locals = default_locals(@options)

			use_engine(@markdown)
			define_statics(@root, *@themes)

			# ファイル監視を行う
			watcher(@root) if @directory_watcher
		end

		def call(env)
			content_type = 'text/html'

			req = Rack::Request.new(env)
			query = Rack::Utils.parse_query(req.query_string)
			path_info = URI.unescape(req.path_info)
			path, ext = split_extname(path_info)

			case path_info
			when '/'
				content = render_with_mustache :index, :markdown
			when /\.css$/
				case @css
				when 'scss', 'sass'
					require 'sass'

					result = pass(env, @statics)
					return result unless result.first == 404

					content_type = 'text/css'
					cache_location = File.expand_path('sass-cache', @tmpdir)
					content = render @css.to_sym, "#{path}.#{@css}", {views: @themes, cache_location: cache_location}
				end
			else
				return pass(env) unless ext && Tilt.registered?(ext)

				if query.has_key?('edit')
					fullpath = File.expand_path(File.join(@root, path_info))

					# @attention リダイレクトはうまく動作しない
					#
					# redirect_url = 'file://' + File.expand_path(File.join(@root, req.path_info))
					# return redirect(redirect_url, 302) if File.exists?(fullpath)
				end

				content = render_with_mustache path.to_sym, ext
			end

			return pass(env) unless content

			[200, {'Content-Type' => content_type}, [content.to_s]]
		end


		# リダイレクト
		def redirect(url, code = 301)
			# 301 = 恒久的, 302 = 一時的, 303, 410
			[code, {'Content-Type' => 'text/html', 'Location' => url}, ['Redirect: ', url]]
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

		# デフォルトの locals を生成する
		def default_locals(locals = {})
			locals = locals.dup

			locals[:page]			||= {}
			locals[:page][:title]	||= locals[:title]

			locals[:app]			||= {}
			locals[:app][:name]		||= MemoRack::name
			locals[:app][:version]	||= MemoRack::VERSION
			locals[:app][:url]		||= MemoRack::HOMEPAGE

			locals
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

		# ファイル監視を行う
		def watcher(path = '.')
			require 'directory_watcher'

			dw = DirectoryWatcher.new path, :pre_load => true
			dw.interval = 1
			dw.stable = 2
			dw.glob = '**/*'
			dw.add_observer { |*args|
				t = Time.now.strftime("%Y-%m-%d %H:%M:%S")
				puts "[#{t}] regeneration: #{args.size} files changed"

				@menu = nil
			}

			dw.start
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
			engine.render(options, locals).force_encoding('UTF-8')
		end

		# レイアウトに mustache を適用してテンプレートエンジンでレンダリングする
		def render_with_mustache(template, engine = :markdown, options = {}, locals = {})
			begin
				options = @options.merge(options)

				@menu = nil unless @directory_watcher	# ファイル監視していない場合はメニューを初期化

				@menu ||= render :markdown, :menu, options
				content = render engine, template, options
				fname = template.to_s.force_encoding('UTF-8')

				locals = @locals.merge(locals)

				locals[:__menu__]		= @menu
				locals[:__content__]	= content
				locals[:page][:title]	= [File.basename(fname), locals[:title]].join(' | ') unless template == :index

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

		# Tilt に登録されている拡張子を集める
		def extnames(extname)
			klass = Tilt[extname]
			Tilt.mappings.select { |key, value| value.member?(klass) }.collect { |key, value| key }
		end

		# 対応フォーマットを取得する
		def collect_formats
			unless @collect_formats
				@collect_formats = {}

				@formats.each { |item|
					if item.kind_of?(Array)
						@collect_formats[item.first] = item
					elsif item.kind_of?(Hash)
						@collect_formats.merge!(item)
					else
						@collect_formats[item] = extnames(item)
					end
				}
			end

			@collect_formats
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
			mdmenu = MdMenu.new({prefix: '/', uri_escape: true, formats: collect_formats})
			Dir.chdir(@root) { |path| mdmenu.collection('.') }
			mdmenu.generate(StringIO.new).string
		end

	end
end
