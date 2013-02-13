# -*- encoding: utf-8 -*-

require 'optparse'
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
		def t(code, options = {})
			options[:scope] ||= [:usage]
			I18n.t(code, options)
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
			opts.on("-p", "--port PORT", String,
					sprintf(t(:port), options[:server][:Port])) { |arg| options[:server][:Port] = arg }
			opts.on("-t", "--theme THEME", String,
					sprintf(t(:theme), options[:theme])) { |arg| options[:theme] = arg }
			opts.on("-h", "--help", t(:help)) { abort opts.help }

			opts.parse!(argv)
			abort opts.help if argv.empty?
		}

		# サブコマンド

		# テンプレートの作成
		def memorack_create(options, *argv)
			path = argv.shift
			abort "File exists '#{path}'" if File.exists?(path)

			require 'fileutils'
			FileUtils.copy_entry(File.expand_path('../template', __FILE__), path)
			puts "Created '#{path}'"
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
