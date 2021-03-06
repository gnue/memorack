# -*- encoding: utf-8 -*-

require 'yaml'
require 'pathname'
require 'rubygems'
require 'i18n'

require 'mustache'
require 'memorack/tilt-mustache'
require 'memorack/mdmenu'
require 'memorack/locals'
require 'memorack/locals/base'


module MemoRack
	class Core
		attr_reader :themes, :options_chain, :suffix, :root

		DEFAULT_APP_OPTIONS = {
			root:				'content/',
			themes_folder:		'themes/',
			tmpdir:				'tmp/',
			theme:				'oreilly',
			markdown:			'redcarpet',
			formats:			['markdown'],
			css:				nil,
			suffix:				'',
			public:				[],
			site:				{},
			requires:			[],
			directory_watcher:	false
		}

		# テンプレートエンジンのオプション
		DEFAULT_TEMPLATE_OPTIONS = {
			tables:				true
		}

		# テンプレートで使用するローカル変数の初期値
		DEFAULT_LOCALS = {
			title:				'memo'
		}

		DEFAULT_OPTIONS = DEFAULT_APP_OPTIONS.merge(DEFAULT_TEMPLATE_OPTIONS).merge(DEFAULT_LOCALS)

		def self.app
			@@app
		end

		def initialize(options={})
			@@app = self

			options = DEFAULT_OPTIONS.merge(to_sym_keys(options))

			@themes_folders = [options[:themes_folder], folder(:themes, :user), folder(:themes)]
			@themes_folders.delete nil
			@themes_folders.reject! { |folder| ! File.directory?(folder) }

			read_config(options[:theme], options)
			read_config(DEFAULT_APP_OPTIONS[:theme], options) if @themes.empty?

			@options = options

			# DEFAULT_APP_OPTIONS に含まれるキーをすべてインスタンス変数に登録する
			DEFAULT_APP_OPTIONS.each { |key, item|
				instance_variable_set("@#{key}".to_sym, options[key])

				# @options からテンプレートで使わないものを削除
				@options.delete(key)
			}

			# プラグインの読込み
			load_plugins

			# ロケールの読込み
			I18n.load_path = @locale_paths
			I18n.backend.load_translations
			I18n.enforce_available_locales = false

			@requires.each { |lib| require lib }
			@locals = default_locals(@options)

			use_engine(@markdown)
		end

		# フォルダ（ディレクトリ）を取得する
		def folder(name, domain = :app)
			@folders ||= {}
			@folders[domain] ||= {}

			unless @folders[domain][name]
				case domain
				when :user
					dir = File.join(ENV['HOME'], '.etc/memorack')
				when :app
					dir = File.dirname(__FILE__)
				else
					return nil
				end
			end

			@folders[domain][name] ||= File.expand_path(name.to_s, dir)
		end

		# テーマのパスを取得する
		def theme_path(theme)
			return nil unless theme

			@themes_folders.each { |folder|
				path = theme && File.join(folder, theme)
				return path if File.exists?(path) && File.directory?(path)
			}

			nil
		end

		# デフォルトの locals を生成する
		def default_locals(locals = {})
			locals = BaseLocals.new(self, locals)
			locals[:site] ||= @site
			locals
		end

		# json/yaml のデータを読込む
		def read_data(name, exts = ['json', 'yml', 'yaml'])
			begin
				exts.each { |ext|
					path = [name, ext].join('.')
					if File.readable?(path)
						data = File.read(path)

						case ext
						when 'json'
							hash = JSON.parse(data)
						when 'yml', 'yaml'
							hash = YAML.load(data)
						end

						data = to_sym_keys(hash) if hash
						return data
					end
				}
			rescue
			end

			nil
		end

		# 設定ファイルを読込む
		def read_config(theme, options = {})
			@themes ||= []
			@options_chain = []
			@locale_paths = []
			@macro_chain = []
			@macro = {}
			@plugins = Set.new

			begin
				require 'json'

				while theme
					dir = theme_path(theme)
					break unless dir
					break if @themes.member?(dir)

					# 設定ファイルのデータをチェインに追加
					theme = add_config_chain(dir, theme)
				end
			rescue
			end

			# デフォルトの設定をチェインに追加
			add_config_chain(File.expand_path('../config', __FILE__))

			# マクロをマージ
			@macro_chain.reverse.each { |macro| @macro.merge!(macro) }

			# オプションをマージ
			@options_chain.reverse.each { |opts| options.merge!(opts) }
			options
		end

		# 設定ファイルのデータをチェインに追加
		def add_config_chain(dir, theme = nil)
			# テーマ・チェインに追加
			@themes << File.join(dir, '') if theme

			# config の読込み
			config = read_data(File.join(dir, 'config'))

			if config
				@options_chain << config
				theme = config[:theme]
			end

			# macro の読込み
			macro = read_data(File.join(dir, 'macro'))
			@macro_chain << macro if macro && macro.kind_of?(Hash)

			# locale の読込み
			@locale_paths += Dir[File.expand_path('locales/*.yml', dir)]

			theme
		end

		# locale を env情報で更新する
		def update_locale(env = ENV)
			locale ||= env['HTTP_ACCEPT_LANGUAGE']
			locale ||= env['LANG'] if env['LANG']
			locale = locale[0, 2].to_sym if locale
			I18n.locale = locale if I18n.available_locales.include?(locale)
		end

		# プラグイン・フォルダを取得する
		def plugins_folders
			unless @plugins_folders
				@plugins_folders = ['plugins/', folder(:plugins, :user), folder(:plugins)]
				@plugins_folders.delete nil
				@plugins_folders.reject! { |folder| ! File.directory?(folder) }

				@themes.each { |theme|
					path = File.join(theme, 'plugins/')
					@plugins_folders.unshift path if File.directory?(path)
				}
			end

			@plugins_folders
		end

		# プラグインを読込む
		def load_plugins
			plugins_folders.reverse.each { |folder|
				Dir.glob(File.join(folder, '*')) { |path|
					name = path.gsub(%r[^#{folder}/], '')
					load_plugin(name, path)
				}
			}
		end

		# プラグインファイルを読込む
		def load_plugin(name, path)
			loaded = false

			if File.directory?(path)
				path = File.join(path, File.basename(path) + '.rb')

				if File.exists?(path)
					require_relative(path)
					loaded = true
				end
			elsif path =~ /\.rb$/
				require_relative(File.expand_path(path))
				loaded = true
			end

			if loaded
				@plugins << name
			end
		end

		# プラグインを読込む（読込み済みのものは読込まない）
		def require_plugin(plugin)
			return if @plugins.include?(plugin)

			plugins_folders.reverse.each { |folder|
				path = File.join(folder, plugin)
				load_plugin(folder, path) if File.exist?(path)
				load_plugin(folder, path + '.rb') if File.exist?(path + '.rb')
			}
		end

		# テンプレートエンジンを使用できるようにする
		def use_engine(engine)
			require engine if engine

			# Tilt で Redcarpet 2.x を使うためのおまじない
			Object.send(:remove_const, :RedcarpetCompat) if defined?(RedcarpetCompat) == 'constant'
		end

		# css の拡張子リストを作成する
		def css_exts
			@css_exts ||= Set.new ['css', *@css]
		end

		# テーマから固定ページのファイルを収集する
		def pages
			unless @pages
				@pages = {}

				@themes.each { |theme|
					folder = File.join(theme, 'pages/')

					if Dir.exists?(folder)
						Dir.chdir(folder) { |dir|
							Dir.glob(File.join('**/*')) { |path|
								path_info, ext = split_extname(path)
								path_info = File.join('', path_info)
								@pages[path_info] ||= File.expand_path(path)
							}
						}
					end
				}
			end

			@pages
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

			dir = options[:views]
			dir = File.join(dir, options[:folder]) if options[:folder]

			if exts
				exts.each { |ext|
					path = File.join(dir, "#{template}.#{ext}")
					return path if File.exists?(path)
				}
			else
				path = File.join(dir, template)
				return path if File.exists?(path)
			end

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
				mustache_templ = []
				mustache_templ << options[:mustache] if options[:mustache]

				options = @options.merge(options)
				locals = @locals.merge(locals)

				locals.define_key(:__content__) { |hash, key|
					if engine
						render engine, template, options
					elsif locals[:directory?]
						# ディレクトリ
						nil
					else
						template
					end
				}

				locals[:directory?] = true if template.kind_of?(Pathname) && template.directory?
				locals[:content?] = true unless template == :index || locals[:directory?]
				locals[:page] = page = Locals[locals[:page] || {}]

				if template.kind_of?(Pathname)
					path = template.to_s
					plugin = PageInfo[path]
					locals[:page] = page = plugin.new(path, page, locals) if plugin
				end

				page.define_key(:name) { |hash, key|
					if hash.kind_of?(PageInfo)
						hash.value(:title)
					elsif template != :index
						fname = locals[:path_info]
						fname ||= template.to_s.force_encoding('UTF-8')
						File.basename(fname)
					end
				}

				# マクロを組込む
				embed_macro(locals, @macro)

				# HTMLページをレンダリングする
				if engine && engine.to_sym == :html
					unless template.kind_of?(Pathname)
						path = file_search(template, @options, [engine])
						return nil unless path
						template = Pathname.new(path)
					end

					locals.define_key(:__content__) { |hash, key| }
					return render :mustache, template, {views: @themes}, locals
				end

				mustache_templ << 'page.html' if locals[:content?]
				mustache_templ << 'index.html'

				mustache_templ.each { |templ|
					path = file_search(templ, {views: @themes}, nil)
					next unless path

					path = Pathname.new(path)
					return render :mustache, path, {views: @themes}, locals
				}

				raise "Not found template #{mustache_templ}"
			rescue => e
				e.to_s
			end
		end

		# Localsクラス 変換する
		def value_to_locals(value)
			case value
			when Locals
			when Hash
				value = Locals[value]
			else
				value = Locals[]
			end

			value
		end

		# マクロを組込む
		def embed_macro(hash, macro, options = {}, locals = hash)
			macro.each { |key, value|
				case value
				when Hash
					if hash[key].kind_of?(Array)
						embed_macro_for_array(hash[key], value, options, locals)
					else
						hash[key] = value_to_locals(hash[key])
						embed_macro(hash[key], value, options, locals)
					end
				when Array
					hash[key] = [] unless hash[key]
					a = hash[key]

					if a.kind_of?(Array)
						value.each_with_index { |item, index|
							if item.kind_of?(Hash)
								a[index] = value_to_locals(a[index])
								embed_macro(a[index], item, options, locals)
							else
								a[index] = item
							end
						}
					end
				else
					hash.define_key(key) { |hash, key|
						if value
							#render :mustache, value, {}, locals

							engine = Tilt.new('.mustache', {}) { value }
							engine.render({}, locals).force_encoding('UTF-8')
						end
					}
				end
			}
		end

		# マクロを配列に組込む
		def embed_macro_for_array(array, macro, options = {}, locals)
			array.each_with_index { |item, index|
				if item.kind_of?(Array)
					embed_macro_for_array(item, macro, options, locals)
				else
					array[index] = value_to_locals(item)
					embed_macro(array[index], macro, options)
				end
			}
		end

		# メニューをレンダリングする
		def render_menu
			@menu = nil unless @directory_watcher	# ファイル監視していない場合はメニューを初期化
			@menu ||= render :markdown, :menu, @options
		end

		# 固定ページをレンダリングする
		def render_page(path_info, locals = {})
			path_info = path_info.gsub(%r[(/|.html)$], '')
			path = pages[path_info]
			return nil unless path

			ext = split_extname(path)[1]
			content = render_with_mustache Pathname.new(path), ext, {}, locals
		end

		# コンテンツをレンダリングする
		def render_content(path_info, locals = {}, exts = enable_exts)
			path = File.join(@root, path_info)

			if File.directory?(path)
				return render_with_mustache Pathname.new(path), nil, {}, locals
			end

			path, ext = split_extname(path_info)

			fullpath = file_search(path_info, @options, exts)

			if fullpath
				path = path_info
				ext = split_extname(fullpath)[1]
			end

			return nil unless ext && Tilt.registered?(ext)

			template = fullpath ? Pathname.new(fullpath) : path.to_sym
			content = render_with_mustache template, ext, {}, locals
		end

		# CSSをレンダリングする
		def render_css(path_info, locals = {})
			return unless @css

			path, = split_extname(path_info)
			options = {views: @themes}

			fullpath = file_search(path, options, css_exts)
			return nil unless fullpath

			ext = split_extname(fullpath)[1]

			case ext
			when 'css'
				return File.binread(fullpath)
			when 'scss', 'sass'
				options[:cache_location] = File.expand_path('sass-cache', @tmpdir)
			end

			render ext, Pathname.new(fullpath), options, locals
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
				value = to_sym_keys(value) if value.kind_of?(Hash)

				memo[key.to_sym] = value

				memo
			}
		end

		# Tilt に登録されている拡張子を集める
		def extnames(extname)
			klass = Tilt[extname]
			r = []

			if Tilt.respond_to?(:mappings)
				r |= Tilt.mappings.select { |key, value| value.member?(klass) }.collect { |key, value| key }
			end

			if Tilt.respond_to?(:default_mapping)
				r |= Tilt.default_mapping.template_map.select { |key, value| value == klass }.collect { |key, value| key }
				r |= Tilt.default_mapping.lazy_map.select { |key, value| value.assoc(klass.to_s) }.collect { |key, value| key }
			end

			r
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

		# コンテンツファイルの収集する
		def contents(options = {})
			default_options = {prefix: '/', suffix: @suffix, uri_escape: true, formats: collect_formats}
			options = default_options.merge(options)

			mdmenu = MdMenu.new(options)
			Dir.chdir(@root) { |path| mdmenu.collection('.') }
			mdmenu
		end

		# パスからコンテント名を取得する
		def content_name(path)
			plugin = PageInfo[path]

			if plugin
				plugin.new(File.expand_path(path, @root))[:title]
			else
				File.basename(path, '.*')
			end
		end

		# テンプレート名
		def self.template_method(name)
			name.kind_of?(Symbol) && "template_#{name}".to_sym
		end

		# テンプレートを作成する
		def self.template(name, &block)
			define_method(self.template_method(name), &block)
		end

	end
end
