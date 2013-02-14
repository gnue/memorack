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
						       #{opts.program_name} server [options] PATH
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

			locale = ENV['LANG'][0, 2].to_sym if ENV['LANG']
			I18n.locale = locale if I18n.available_locales.include?(locale)
		end

		# I18n で翻訳する
		def t(code, locals = nil, options = {})
			options[:scope] ||= [:usage]
			text = I18n.t(code, options)
			text = sprintf(text, locals[code], options) if locals
			text
		end

		# テーマ一覧を表示する
		def show_themes(domain, themes)
			return unless File.directory?(themes)

			puts "#{domain}:"

			Dir.foreach(themes) { |file|
				next if /^\./ =~ file
				puts "  #{file}"
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
		define_options(:server, '[options] PATH') { |opts, argv, options|
			default_options = {
					theme: 'oreilly',

					server: {
						environment:	ENV['RACK_ENV'] || 'development',
						Port:			9292,
						Host:			'0.0.0.0',
						AccessLog:		[],
					}
				}

			options.merge!(default_options)

			opts.separator ""
			opts.on("-p", "--port PORT", String, t(:port, options)) { |arg| options[:server][:Port] = arg }
			opts.on("-t", "--theme THEME", String, t(:theme, options)) { |arg| options[:theme] = arg }
			opts.on("-h", "--help", t(:help)) { abort opts.help }

			opts.parse!(argv)
			abort opts.help if argv.empty?
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
			theme = argv.shift

			themes = File.expand_path("../themes", __FILE__)
			dir = options[:dir]

			if theme
				from = File.join(themes, theme)
				"Theme not exists '#{theme}'" unless File.directory?(from)

				if options[:copy]
					# テーマをコピー
					path = File.directory?(dir) ? File.join(dir, theme) : theme
					FileUtils.copy_entry(from, path)
					puts "Created '#{path}'"
				else
					# テーマの情報（継承関係）を表示
					app = MemoRack::MemoApp.new(nil, theme: theme, root: dir)

					theme_chain = app.theme_chain.collect { |path|
						theme_path = File.dirname(path)
						name = File.basename(theme_path)

						File.dirname(theme_path) == themes ? "[#{name}]" : name
					}

					puts theme_chain.join(' --> ')
				end
			else
				# テーマ一覧を表示
				show_themes('MemoRack', themes)
				show_themes('User', dir)
			end
		end

		# サーバーの実行
		def memorack_server(options, *argv)
			path = argv.shift
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
	end
end
