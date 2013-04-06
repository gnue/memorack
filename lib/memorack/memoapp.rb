# -*- encoding: utf-8 -*-

require 'pathname'
require 'rubygems'
require 'rack'
require 'uri'

require 'memorack/tilt-mustache'
require 'memorack/mdmenu'
require 'memorack/locals'

module MemoRack
	class MemoApp
		attr_reader :themes, :options_chain

		DEFAULT_APP_OPTIONS = {
			root:				'content/',
			themes_folder:		'themes/',
			tmpdir:				'tmp/',
			theme:				'basic',
			markdown:			'redcarpet',
			formats:			['markdown'],
			css:				nil,
			suffix:				'',
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
			read_config(DEFAULT_APP_OPTIONS[:theme], options) if @themes.empty?

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
			watcher(@root, @directory_watcher) if @directory_watcher
		end

		def call(env)
			content_type = 'text/html'

			path_info = unescape_path_info(env)

			case path_info
			when '/'
				content = render_with_mustache :index, :markdown
			when /\.css$/
				result = pass(env, @statics)
				return result unless result.first == 404

				begin
					content_type = 'text/css'
					content = render_css(env, path_info)
				rescue Errno::ENOENT => e
					return error(env, 404)
				end
			else
				content = render_content(env, path_info)
			end

			return [200, {'Content-Type' => content_type}, [content.to_s]] if content

			pass(env) { |env, code|
				error(env, code)
			} 
		end

		# PATH_INFO を unescape して取出す
		def unescape_path_info(env)
			path_info = URI.unescape(env['PATH_INFO'])
			path_info.force_encoding('UTF-8')
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
			locals = Locals[locals]

			locals[:app]			||= Locals[]
			locals[:app][:name]		||= MemoRack::name
			locals[:app][:version]	||= MemoRack::VERSION
			locals[:app][:url]		||= MemoRack::HOMEPAGE

			locals.define_key(:__menu__) { |hash, key|
				@menu = nil unless @directory_watcher	# ファイル監視していない場合はメニューを初期化
				@menu ||= render :markdown, :menu, @options
			}

			locals
		end

		# 設定ファイルを読込む
		def read_config(theme, options = {})
			@themes ||= []
			@options_chain = []
			@theme_chain = []

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
					@options_chain << to_sym_keys(JSON.parse(data))

					theme = @options_chain.last[:theme]
				end
			rescue
			end

			# オプションをマージ
			@options_chain.reverse.each { |opts| options.merge!(opts) }
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

			return yield(env, 404) if block_given?

			error(env, 404, 'File not found: ')
		end

		# エラー
		def error(env, code, body = nil, content_type = 'text/plain; charset=utf-8')
			path_info = unescape_path_info(env)

			if body
				body = [body.to_s, path_info] unless body.kind_of?(Array)
			else
				fullpath = file_search("/#{code}", {views: @themes})
				ext = split_extname(fullpath)[1]
				locals = {env: env, path_info: path_info, page: {name: "Error #{code}"}}

				if ext && Tilt.registered?(ext)
					template = Pathname.new(fullpath)
				else
					template = "Error #{code}: #{path_info}"
					ext = nil
				end

				content = render_with_mustache template, ext, {mustache: 'error.html'}, locals

				if content
					content_type = 'text/html'
					body = [content.to_s]
				else
					body = ["Error #{code}: ", path_info]
				end
			end

			[code, {'Content-Type' => content_type, }, body]
		end

		# ファイル監視を行う
		def watcher(path = '.', interval = 1.0)
			require 'directory_watcher'

			interval = 1.0 if interval == true # 旧バージョンとの互換性のため

			dw = DirectoryWatcher.new path, :pre_load => true
			dw.interval = interval
			dw.stable = 2
			dw.glob = '**/*'
			dw.add_observer { |*args|
				t = Time.now.strftime("%Y-%m-%d %H:%M:%S")
				puts "[#{t}] regeneration: #{args.size} files changed"

				@menu = nil
			}

			dw.start
		end

		# ファイルを探す
		def file_search(template, options = {}, exts = enable_exts)
			options = {views: @root}.merge(options)

			if options[:views].kind_of?(Array)
				err = nil

				options[:views].each { |views|
					options[:views] = views

					begin
						path = file_search(template, options, exts)
						return path if path
					rescue Errno::ENOENT => e
						err = e
					end
				}

				raise err if err
				return nil
			end

			exts.each { |ext|
				path = File.join(options[:views], "#{template}.#{ext}")
				return path if File.exists?(path)
			}

			return nil
		end

		# テンプレートエンジンで render する
		def render(engine, template, options = {}, locals = {})
			options = {views: @root}.merge(options)

			if template.kind_of?(Pathname)
				path = template
			elsif options[:views].kind_of?(Array)
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
			else
				fname = template.kind_of?(String) ? template : "#{template}.#{engine}"
				path = File.join(options[:views], fname)
			end

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
				mustache_templ = options[:mustache] || 'index.html'

				options = @options.merge(options)
				locals = @locals.merge(locals)

				locals.define_key(:__content__) { |hash, key|
					if engine
						render engine, template, options
					else
						template
					end
				}

				locals[:content] = true unless template == :index
				locals[:page] = page = Locals[locals[:page] || {}]

				page.define_key(:name) { |hash, key|
					unless template == :index
						fname = locals[:path_info]
						fname ||= template.to_s.force_encoding('UTF-8')
						File.basename(fname)
					end
				}

				page.define_key(:title) { |hash, key|
					page_title = home_title = locals[:title]
					page_name = hash[:name]
					page_title = "#{page_name} | #{home_title}" if page_name

					page_title
				}

				render :mustache, mustache_templ, {views: @themes}, locals
			rescue => e
				e.to_s
			end
		end

		# コンテンツをレンダリングする
		def render_content(env, path_info)
			path, ext = split_extname(path_info)

			if @suffix == ''
				path = path_info
				fullpath = file_search(path, @options)
				return nil unless fullpath

				ext = split_extname(fullpath)[1]
			end

			return nil unless ext && Tilt.registered?(ext)

			req = Rack::Request.new(env)
			query = Rack::Utils.parse_query(req.query_string)
			locals = {env: env, path_info: path_info}

			if query.has_key?('edit')
				fullpath = File.expand_path(File.join(@root, "#{path}.#{ext}")) unless fullpath

				# @attention リダイレクトはうまく動作しない
				#
				# redirect_url = 'file://' + File.expand_path(File.join(@root, req.path_info))
				# return redirect(redirect_url, 302) if File.exists?(fullpath)
			end

			template = fullpath ? Pathname.new(fullpath) : path.to_sym
			content = render_with_mustache template, ext, {}, locals
		end

		# CSSをレンダリングする
		def render_css(env, path_info)
			return unless @css

			exts = @css
			exts = [exts] unless exts.kind_of?(Array)
			path, = split_extname(path_info)
			options = {views: @themes}

			fullpath = file_search(path, options, exts)
			return nil unless fullpath

			ext = split_extname(fullpath)[1]

			case ext
			when 'scss', 'sass'
				options[:cache_location] = File.expand_path('sass-cache', @tmpdir)
			end

			render ext, Pathname.new(fullpath), options
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

		# 対応している拡張子
		def enable_exts
			@enable_exts ||= collect_formats.values.flatten
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
			mdmenu = MdMenu.new({prefix: '/', suffix: @suffix, uri_escape: true, formats: collect_formats})
			Dir.chdir(@root) { |path| mdmenu.collection('.') }
			mdmenu.generate(StringIO.new).string
		end

	end
end
