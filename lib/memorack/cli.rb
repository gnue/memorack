require 'optparse'

module MemoRack
  class CLI

    def self.execute(stdout, argv = [])
      options = {theme: 'oreilly'}
      mandatory_options = %w(  )

      server_options = {
        :environment => ENV['RACK_ENV'] || 'development',
        :Port        => 9292,
        :Host        => '0.0.0.0',
        :AccessLog   => [],
      }

      parser = OptionParser.new do |opts|
        opts.version = MemoRack::VERSION

        opts.banner = <<-BANNER.gsub(/^          /,'')
          Usage: #{opts.program_name} create [options] PATH
                 #{opts.program_name} server [options] PATH
        BANNER

        opts.separator ""
        opts.on("-h", "--help",
                "Show this help message.") { abort opts.help }

        if mandatory_options && mandatory_options.find { |option| options[option.to_sym].nil? }
          abort opts.help
        end
      end

      # コマンド名
      cmd = parser.program_name

      # サブコマンドのオプション解析
      subparsers = Hash.new {|h,k| abort "#{cmd}: '#{k}' is not a #{cmd} command. See '#{cmd} --help'" }

      # create のオプション解析
      subparsers['create'] = OptionParser.new do |opts|
        opts.banner = "Usage: #{cmd} create [options] PATH"

        opts.on("-h", "--help",
                "Show this help message.") { abort opts.help }
      end

      # server のオプション解析
      subparsers['server'] = OptionParser.new do |opts|
        opts.banner = "Usage: #{cmd} server [options] PATH"

        opts.separator ""
        opts.separator "Server options:"
        opts.on("-p", "--port PORT", String,
                "use PORT (default: #{server_options[:Port]})") { |arg| server_options[:Port] = arg }
        opts.on("-t", "--theme THEME", String,
                "use THEME (default: oreilly)") { |arg| options[:theme] = arg }
        opts.on("-h", "--help",
                "Show this help message.") { abort opts.help }
      end

      parser.order!(argv)
      abort parser.help if argv.empty?

      subcmd = argv.shift
      subparser = subparsers[subcmd]
      subparser.parse!(argv)

      # do stuff
      case subcmd
      when 'create'
        path = argv.shift
        abort subparser.help unless path
		abort "File exists '#{path}'" if File.exists?(path)

        require 'fileutils'
        FileUtils.copy_entry(File.expand_path('../template', __FILE__), path)
        stdout.puts "Created '#{path}'"
      when 'server'
        path = argv.shift
        abort subparser.help unless path

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
      else
        abort parser.help
      end
    end
  end
end