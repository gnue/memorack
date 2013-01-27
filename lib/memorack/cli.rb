require 'optparse'

module Memorack
  class CLI
    def self.execute(stdout, arguments=[])

      # NOTE: the option -p/--path= is given as an example, and should be replaced in your application.

      options = {port: 9292}
      mandatory_options = %w(  )

      parser = OptionParser.new do |opts|
        opts.banner = <<-BANNER.gsub(/^          /,'')
          This application is wonderful because...

          Usage: #{File.basename($0)} [options]

          Options are:
        BANNER
        opts.separator ""
        opts.on("-p", "--port PORT", String,
                "Use server port") { |arg| options[:port] = arg }
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
	  else
        stdout.puts parser.help
      end
    end
  end
end