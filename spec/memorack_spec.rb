# -*- encoding: utf-8 -*-

require File.expand_path('../spec_helper', __FILE__)
require 'memorack'
require 'memorack/cli'


describe MemoRack do
	class String
		# １行目のインデントだけ全体のインデントを削除する
		def cut_indent(prefix = '')
			prefix = Regexp.escape(prefix)

			if self =~ /^(\s+#{prefix})/
				indent = Regexp.escape($1)
				self.gsub(/^#{indent}/,'')
			else
				self
			end
		end
	end

	# MemoRack::CLI.run を呼出す
	def memorack(*argv)
		program_name = $0

		begin
			$0 = 'memorack'
			MemoRack::CLI.run(argv)
		rescue SystemExit => err
			@abort = err.inspect
		ensure
			$0 = program_name
		end
	end

	# テンプレートを作成して cd する
	def chmemo(name = 'memo')
		Dir.chdir(@tmpdir) {
			proc { memorack 'create', name }.must_output "Created '#{name}'\n"

			Dir.chdir(name) {
				yield(name)
			}
		}
	end

	before do
		require 'tmpdir'
		@tmpdir = Dir.mktmpdir
	end

	describe "usage" do
		describe "en" do
			before do
				ENV['LANG'] = 'en_US.UTF-8'
			end

			it "usage" do
				proc { memorack '-h' }.must_output nil, <<-EOD.cut_indent
					Usage: memorack create [options] PATH
					       memorack theme  [options] [THEME]
					       memorack server [options] PATH

					    -h, --help                       Show this message
				EOD
			end

			it "create" do
				proc { memorack 'create', '-h' }.must_output nil, <<-EOD.cut_indent
					Usage: memorack create [options] PATH
					    -h, --help                       Show this message
				EOD
			end

			it "theme" do
				proc { memorack 'theme', '-h' }.must_output nil, <<-EOD.cut_indent
					Usage: memorack theme [options] [THEME]

					    -c, --copy                       Copy theme
					    -d, --dir DIR                    Theme directory (default: themes)
					    -h, --help                       Show this message
				EOD
			end

			it "server" do
				proc { memorack 'server', '-h' }.must_output nil, <<-EOD.cut_indent
					Usage: memorack server [options] PATH

					    -p, --port PORT                  use PORT (default: 9292)
					    -t, --theme THEME                use THEME (default: oreilly)
					    -h, --help                       Show this message
				EOD
			end
		end

		describe "ja" do
			before do
				ENV['LANG'] = 'ja_JP.UTF-8'
			end

			it "usage" do
				proc { memorack '-h' }.must_output nil, <<-EOD.cut_indent
					Usage: memorack create [options] PATH
					       memorack theme  [options] [THEME]
					       memorack server [options] PATH

					    -h, --help                       このメッセージを表示
				EOD
			end

			it "create" do
				proc { memorack 'create', '-h' }.must_output nil, <<-EOD.cut_indent
					Usage: memorack create [options] PATH
					    -h, --help                       このメッセージを表示
				EOD
			end


			it "theme" do
				proc { memorack 'theme', '-h' }.must_output nil, <<-EOD.cut_indent
					Usage: memorack theme [options] [THEME]

					    -c, --copy                       テーマをコピーする
					    -d, --dir DIR                    テーマのディレクトリー（省略値: themes）
					    -h, --help                       このメッセージを表示
				EOD
			end

			it "server" do
				proc { memorack 'server', '-h' }.must_output nil, <<-EOD.cut_indent
					Usage: memorack server [options] PATH

					    -p, --port PORT                  ポートを使う (省略値: 9292)
					    -t, --theme THEME                テーマを使う (省略値: oreilly)
					    -h, --help                       このメッセージを表示
				EOD
			end
		end
	end

	describe "create" do
		it "create" do
			name = 'memo'

			Dir.chdir(@tmpdir) {
				proc { memorack 'create', name }.must_output "Created '#{name}'\n"
				`cd #{name}; find . -print`.must_equal <<-EOD.cut_indent
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
			proc { memorack 'theme' }.must_output <<-EOD.cut_indent
				MemoRack:
				  basic
				  oreilly
			EOD
		end

		it "theme(with user)" do
			chmemo { |name|
				proc { memorack 'theme' }.must_output <<-EOD.cut_indent
					MemoRack:
					  basic
					  oreilly
					User:
					  custom
				EOD
			}
		end

		it "theme THEME" do
			chmemo { |name|
				proc { memorack 'theme', 'custom' }.must_output <<-EOD.cut_indent
					custom --> [oreilly] --> [basic]
					  config.json
					  index.md
				EOD
			}
		end

		it "theme -c THEME" do
			theme = 'basic'

			chmemo { |name|
				proc { memorack 'theme', '-c', theme }.must_output "Created 'themes/#{theme}'\n"

				`cd themes/#{theme}; find . -print`.must_equal <<-EOD.cut_indent
					.
					./2-column.scss
					./404.md
					./basic-styles.scss
					./config.json
					./error.html
					./index.html
					./styles.scss
				EOD
			}
		end

		it "theme -c THEME/index.html" do
			theme = 'basic'
			fname = 'index.html'

			chmemo { |name|
				proc { memorack 'theme', '-c', File.join(theme, fname) }.must_output "Created '#{fname}'\n"
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
