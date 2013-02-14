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
		it "theme" do
			proc { memorack 'theme' }.must_output <<-EOD.gsub(/^\t+/,'')
				MemoRack:
				  basic
				  oreilly
			EOD
		end

		it "theme(with user)" do
			name = 'memo'

			Dir.chdir(@tmpdir) {
				proc { memorack 'create', name }.must_output "Created '#{name}'\n"

				Dir.chdir(name) {
					proc { memorack 'theme' }.must_output <<-EOD.gsub(/^\t+/,'')
						MemoRack:
						  basic
						  oreilly
						User:
						  custom
					EOD
				}
			}
		end

		it "theme THEME" do
			name = 'memo'

			Dir.chdir(@tmpdir) {
				proc { memorack 'create', name }.must_output "Created '#{name}'\n"

				Dir.chdir(name) {
					proc { memorack 'theme', 'custom' }.must_output <<-EOD.gsub(/^\t+/,'')
						custom --> [oreilly] --> [basic]
						  config.json
						  index.md
					EOD
				}
			}
		end

		it "theme -c THEME" do
			name = 'memo'
			theme = 'basic'

			Dir.chdir(@tmpdir) {
				proc { memorack 'create', name }.must_output "Created '#{name}'\n"

				Dir.chdir(name) {
					proc { memorack 'theme', '-c', theme }.must_output "Created 'themes/#{theme}'\n"

					`cd themes/#{theme}; find . -print`.must_equal <<-EOD.gsub(/^\t+/,'')
						.
						./2-column.scss
						./basic-styles.scss
						./config.json
						./index.html
						./styles.scss
					EOD
				}
			}
		end

		it "theme -c THEME/index.html" do
			name = 'memo'
			theme = 'basic'
			fname = 'index.html'

			Dir.chdir(@tmpdir) {
				proc { memorack 'create', name }.must_output "Created '#{name}'\n"

				Dir.chdir(name) {
					proc { memorack 'theme', '-c', File.join(theme, fname) }.must_output "Created '#{fname}'\n"
				}
			}
		end
	end

	describe "server" do
		it "server"
	end

	after do
		FileUtils.remove_entry_secure @tmpdir
	end
end
