require 'optparse'

module Memorack
  class CLI
    def self.execute(stdout, arguments=[])

      # NOTE: the option -p/--path= is given as an example, and should be replaced in your application.

      options = {port: 9292, theme: 'oreilly'}
      mandatory_options = %w(  )

      parser = OptionParser.new do |opts|
        opts.banner = <<-BANNER.gsub(/^          /,'')
          Usage: #{File.basename($0)} create PATH
                 #{File.basename($0)} server [options] PATH
        BANNER

        opts.separator ""
        opts.separator "Server options:"
        opts.on("-p", "--port PORT", String,
                "use PORT (default: #{options[:port]})") { |arg| options[:port] = arg }
        opts.on("-t", "--theme THEME", String,
                "use THEME (default: oreilly)") { |arg| options[:theme] = arg }

        opts.separator ""
        opts.separator "Common options:"
        opts.on("-h", "--help",
                "Show this help message.") { stdout.puts opts; exit }
        opts.parse!(arguments)

        if mandatory_options && mandatory_options.find { |option| options[option.to_sym].nil? }
          stdout.puts opts; exit
        end
      end

      subcmd, path = arguments

      # do stuff
      case subcmd
      when 'create'
        require 'fileutils'
        FileUtils.copy_entry(File.expand_path('../template', __FILE__), path)
        stdout.puts "created #{path}"
      when 'server'
        require 'rack/builder'
        require 'rack/handler/webrick'
        app = Rack::Builder.new {
          require 'memorack'
          run MemoRack::MemoApp.new(nil, theme: options[:theme], root: path)
        }
        Rack::Server.new(:app => app, :Port => options[:port]).start
      else
        stdout.puts parser.help
      end
    end
  end
end