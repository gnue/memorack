# -*- encoding: utf-8 -*-

require 'optparse'
require 'fileutils'
require 'rubygems'
require 'i18n'


module MemoRack
	class CLI

		def self.run(argv = ARGV, options = {})
			CLI.new.run(argv, options)
		end

		def initialize
			i18n_init
		end

		def run(argv = ARGV, options = {})
			subcmd = nil

			parser = OptionParser.new do |opts|
				begin
					opts.version = LONG_VERSION || VERSION

					opts.banner = <<-BANNER.gsub(/^\t+/,'')
						Usage: #{opts.program_name} create [options] PATH
						       #{opts.program_name} theme  [options] [THEME]
						       #{opts.program_name} server [options] [PATH]
						       #{opts.program_name} build  [options] [PATH]
					BANNER

					opts.separator ""
					opts.on("-h", "--help", t(:help)) { abort opts.help }

					opts.order!(argv)

					subcmd = argv.shift
					abort opts.help unless subcmd
					abort opts.help unless has_action?(subcmd)
				rescue => e
					abort e.to_s
				end
			end

			action(subcmd, argv, options)
		end

		# I18n を初期化する
		def i18n_init
			I18n.load_path = Dir[File.expand_path('../locales/*.yml', __FILE__)]
			I18n.backend.load_translations
			I18n.enforce_available_locales = false

			locale = ENV['LANG'][0, 2].to_sym if ENV['LANG']
			I18n.locale = locale if I18n.available_locales.include?(locale)
		end

		# I18n で翻訳する
		def t(code, locals = {}, options = {})
			options[:scope] ||= [:usage]
			sprintf(I18n.t(code, options), locals)
		end

		# ディレクトリを繰返す
		def dir_earch(dir, match = '**/*', flag = File::FNM_DOTMATCH)
			Dir.chdir(dir) { |d|
				Dir.glob(match, flag).sort.each { |file|
					next if File.basename(file) =~ /^[.]{1,2}$/
					file = File.join(file, '') if File.directory?(file)
					yield(file)
				}
			}
		end

		# テーマ一覧を表示する
		def show_themes(domain, themes)
			return unless File.directory?(themes)

			puts "#{domain}:"

			Dir.open(themes) { |dir|
				dir.sort.each { |file|
					next if /^\./ =~ file
					puts "  #{file}"
				}
			}
		end

		# サブコマンドが定義されているか？
		def has_action?(command)
			respond_to? "memorack_#{command}"
		end

		# サブコマンドの実行
		def action(command, argv, options = {})
			command = command.gsub(/-/, '_')

			# オプション解析
			options_method = "options_#{command}"
			options.merge!(send(options_method, argv)) if respond_to?(options_method)

			send("memorack_#{command}", options, *argv)
		end

		# サブコマンド・オプションのバナー作成
		def banner(opts, method, *args)
			subcmd = method.to_s.gsub(/^.+_/, '')
			["Usage: #{opts.program_name} #{subcmd}", *args].join(' ')
		end

		# オプション解析を定義する
		def self.define_options(command, *banner, &block)
			define_method "options_#{command}" do |argv|
				options = {}

				OptionParser.new { |opts|
					begin
						opts.banner = banner(opts, command, *banner)
						instance_exec(opts, argv, options, &block)
					rescue => e
						abort e.to_s
					end
				}

				options
			end
		end

		# オプション解析

		# テンプレートの作成
		define_options(:create, '[options] PATH') { |opts, argv, options|
			opts.on("-h", "--help", t(:help)) { abort opts.help }

			opts.parse!(argv)
			abort opts.help if argv.empty?
		}

		# テーマ関連の操作
		define_options(:theme, '[options] [THEME]') { |opts, argv, options|
			default_options = {dir: 'themes'}

			options.merge!(default_options)

			opts.separator ""
			opts.on("-c", "--copy", t(:copy)) { options[:copy] = true }
			opts.on("-d", "--dir DIR", t(:dir, options)) { |arg| options[:dir] = arg }
			opts.on("-h", "--help", t(:help)) { abort opts.help }

			opts.parse!(argv)
		}

		# サーバーの実行
		define_options(:server, '[options] [PATH]') { |opts, argv, options|
			default_options = {
					theme: 'custom',

					server: {
						environment:	ENV['RACK_ENV'] || 'development',
						Port:			9292,
						Host:			'0.0.0.0',
						AccessLog:		[],
					}
				}

			options.merge!(default_options)

			opts.separator ""
			opts.on("-p", "--port PORT", String,
				t(:port, options[:server])) { |arg| options[:server][:Port] = arg }
			opts.on("-t", "--theme THEME", String,
				t(:theme, options)) { |arg| options[:theme] = arg }
			opts.on("-h", "--help", t(:help)) { abort opts.help }

			opts.parse!(argv)
		}

		# 静的サイトのビルド
		define_options(:build, '[options] [PATH]') { |opts, argv, options|
			default_options = {
					output:	'_site',
					theme:	'custom',
					url:	'',

					local:		false,
					prettify:	false,
					index:		false,
				}

			options.merge!(default_options)

			opts.separator ""
			opts.on("-o", "--output DIRECTORY", String,
				t(:output, options)) { |arg| options[:output] = arg }
			opts.on("-t", "--theme THEME", String,
				t(:theme, options)) { |arg| options[:theme] = arg }
			opts.on("--url URL", String,
				t(:url, options)) { |arg| options[:url] = arg }
			opts.on("--local",
				t(:local)) { options[:local] = true }
			opts.on("--prettify",
				t(:prettify)) { options[:prettify] = true }
			opts.on("--index",
				t(:index)) { options[:index] = true }
			opts.on("-h", "--help", t(:help)) { abort opts.help }

			opts.parse!(argv)

			options[:url] = 'file://' + File.expand_path(options[:output]) if options[:local]
			options[:suffix] = '' if options[:prettify]
		}


		# サブコマンド

		# テンプレートの作成
		def memorack_create(options, *argv)
			path = argv.shift
			abort "File exists '#{path}'" if File.exists?(path)

			FileUtils.copy_entry(File.expand_path('../template', __FILE__), path)
			puts "Created '#{path}'"
		end

		# テーマ関連の操作
		def memorack_theme(options, *argv)
			theme_or_file = argv.shift

			themes = File.expand_path("../themes", __FILE__)
			dir = options[:dir]

			if theme_or_file
				theme = theme_or_file.gsub(%r(/.*), '')

				if options[:copy]
					# テーマをコピー
					theme_dir = File.join(themes, theme)
					abort "Theme not exists '#{theme}'" unless File.directory?(theme_dir)

					from = File.join(themes, theme_or_file)
					abort "File not exists '#{theme_or_file}'" unless File.exists?(from)

					path = name = File.basename(from)
					path = File.join(dir, name) if File.directory?(dir) && File.directory?(from)

					FileUtils.copy_entry(from, path)
					puts "Created '#{path}'"
				else
					# テーマの情報を表示
					app = MemoRack::MemoApp.new(nil, theme: theme, root: dir)
					theme_dir = app.themes.first

					abort "Theme not exists '#{theme}'" unless theme_dir

					# 継承関係の表示
					theme_chain = app.themes.collect { |path|
						name = File.basename(path)
						File.dirname(path) == themes ? "[#{name}]" : name
					}

					puts theme_chain.join(' --> ')

					# ファイル一覧の表示
					dir_earch(theme_dir) { |file|
						puts "  #{file}"
					}
				end
			else
				# テーマ一覧を表示
				show_themes('MemoRack', themes)
				show_themes('User', dir)
			end
		end

		# サーバーの実行
		def memorack_server(options, *argv)
			path ||= argv.shift
			path ||= 'content'
			abort "Directory not exists '#{path}'" unless File.exists?(path)
			abort "Not directory '#{path}'" unless File.directory?(path)

			server_options = options[:server]

			# サーバーの起動
			require 'rack/builder'
			require 'rack/handler/webrick'
			app = Rack::Builder.new {
				require 'memorack'
				require 'tmpdir'

				Dir.mktmpdir do |tmpdir|
					run MemoRack::MemoApp.new(nil, theme: options[:theme], root: path, tmpdir: tmpdir)
				end
			}

			server_options[:app] = app
			Rack::Server.new(server_options).start
		end

		# 静的サイトのビルド
		def memorack_build(options, *argv)
			path = argv.shift
			path = 'content/' unless path
			abort "Directory not exists '#{path}'" unless File.exists?(path)

			require 'memorack/builder'
			require 'tmpdir'

			Dir.mktmpdir do |tmpdir|
				site = {}
				site[:url] = File.join(options[:url], '').gsub(/\/$/, '') if options[:url]

				builder = MemoRack::Builder.new(theme: options[:theme], root: path, tmpdir: tmpdir, site: site)
				builder.generate(options)
			end

			puts "Build '#{path}' -> '#{options[:output]}'"
		end
	end
end
