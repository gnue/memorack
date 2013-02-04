require 'optparse'

module MemoRack
	class CLI

		def self.run(argv = ARGV)
			subcmd = nil

			parser = OptionParser.new do |opts|
				begin
					opts.version = MemoRack::VERSION

					opts.banner = <<-BANNER.gsub(/^					/,'')
						Usage: #{opts.program_name} create [options] PATH
						       #{opts.program_name} server [options] PATH
					BANNER

					opts.separator ""
					opts.on("-h", "--help", "Show this help message.") { abort opts.help }

					opts.order!(argv)

					subcmd = argv.shift
					abort opts.help unless subcmd
					abort opts.help unless self.has_action?(subcmd)
				rescue => e
					abort e.to_s
				end
			end

			cli = self.new
			cli.action(subcmd, *argv)
		end

		# サブコマンドが定義されているか？
		def self.has_action?(command)
			method_defined? "memorack_#{command}"
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
					opts.on("-h", "--help", "Show this help message.") { abort opts.help }

					opts.order!(args)

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
							"use PORT (default: #{server_options[:Port]})") { |arg| server_options[:Port] = arg }
					opts.on("-t", "--theme THEME", String,
							"use THEME (default: oreilly)") { |arg| options[:theme] = arg }
					opts.on("-h", "--help", "Show this help message.") { abort opts.help }

					opts.order!(args)

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
