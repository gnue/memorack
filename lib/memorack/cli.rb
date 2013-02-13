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

			action(subcmd, *argv)
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
		def action(command, *args)
			command = command.gsub(/-/, '_')
			send "memorack_#{command}", *args
		end

		# サブコマンド・オプションのバナー作成
		def banner(opts, method, *args)
			subcmd = method.to_s.gsub(/^.+_/, '')
			["Usage: #{opts.program_name} #{subcmd}", *args].join(' ')
		end

		# テンプレートの作成
		def memorack_create(*args)
			options = {}
			path = nil

			# オプション解析
			OptionParser.new do |opts|
				begin
					opts.banner = banner(opts, __method__, '[options] PATH')
					opts.on("-h", "--help", t(:help)) { abort opts.help }

					opts.parse!(args)

					path = args.shift
					abort opts.help unless path
				rescue => e
					abort e.to_s
				end
			end

			abort "File exists '#{path}'" if File.exists?(path)

			require 'fileutils'
			FileUtils.copy_entry(File.expand_path('../template', __FILE__), path)
			puts "Created '#{path}'"
		end

		# サーバーの実行
		def memorack_server(*args)
			options = {theme: 'oreilly'}
			path = nil

			server_options = {
				:environment	=> ENV['RACK_ENV'] || 'development',
				:Port			=> 9292,
				:Host			=> '0.0.0.0',
				:AccessLog		=> [],
			}

			# オプション解析
			OptionParser.new do |opts|
				begin
					opts.banner = banner(opts, __method__, '[options] PATH')

					opts.separator ""
					opts.on("-p", "--port PORT", String,
							sprintf(t(:port), server_options[:Port])) { |arg| server_options[:Port] = arg }
					opts.on("-t", "--theme THEME", String,
							sprintf(t(:theme), options[:theme])) { |arg| options[:theme] = arg }
					opts.on("-h", "--help", t(:help)) { abort opts.help }

					opts.parse!(args)

					path = args.shift
					abort opts.help unless path
				rescue => e
					abort e.to_s
				end
			end

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
