# -*- encoding: utf-8 -*-

require File.expand_path('../spec_helper', __FILE__)
require 'memorack'
require 'memorack/cli'


describe MemoRack do
	# MemoRack::CLI.run を呼出す
	def memorack(*argv)
		begin
			MemoRack::CLI.run(argv)
		rescue SystemExit => err
			@abort = err.inspect
		end
	end

	before do
		require 'tmpdir'
		@tmpdir = Dir.mktmpdir
	end

	describe "create" do
		it "create" do
			name = 'memo'

			Dir.chdir(@tmpdir) {
				proc { memorack 'create', name }.must_output "Created '#{name}'\n"
				`cd #{name}; find . -print`.must_equal <<-EOD.gsub(/^\t+/,'')
					.
					./.gitignore
					./.powenv
					./config.ru
					./content
					./content/README.md
					./Gemfile
					./themes
					./themes/custom
					./themes/custom/config.json
					./themes/custom/index.md
				EOD
			}
		end

		it "create(File exists)" do
			name = 'memo'

			Dir.chdir(@tmpdir) {
				Dir.mkdir name
				proc { memorack 'create', name }.must_output nil, "File exists '#{name}'\n"
			}
		end
	end

	describe "theme" do
		it "theme"
	end

	describe "server" do
		it "server"
	end

	after do
		FileUtils.remove_entry_secure @tmpdir
	end
end
