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

	# パッチをあてる
	def patch(name)
		path = File.expand_path("../patches/#{name}", __FILE__)
		if File.directory?(path)
			Dir[File.join(path, '*.patch')].each { |path|
				`patch -p1 < "#{path}"`
			}
		else
			path += '.patch'
			`patch -p1 < "#{path}"`
		end
	end

	# git でパッチをあてる
	def git_am(name)
		unless File.exists?('.git')
			`git init`
			`git add .`
			`git commit -m "first commit"`
		end

		path = File.expand_path("../patches/#{name}", __FILE__)
		if File.directory?(path)
			Dir[File.join(path, '*.patch')].each { |path|
				`git am -3 "#{path}"`
			}
		else
			path += '.patch'
			`git am -3 "#{path}"`
		end
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
					       memorack server [options] [PATH]
					       memorack build  [options] [PATH]

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
					Usage: memorack server [options] [PATH]

					    -p, --port PORT                  use PORT (default: 9292)
					    -t, --theme THEME                use THEME (default: custom)
					    -h, --help                       Show this message
				EOD
			end

			it "build" do
				proc { memorack 'build', '-h' }.must_output nil, <<-EOD.cut_indent
					Usage: memorack build [options] [PATH]

					    -o, --output DIRECTORY           Output directory (default: _site)
					    -t, --theme THEME                use THEME (default: custom)
					        --url URL                    Site URL (default: )
					        --local                      Site URL is output directory
					        --prettify                   prettify URL
					        --index                      output index.html of sub directory
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
					       memorack server [options] [PATH]
					       memorack build  [options] [PATH]

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
					Usage: memorack server [options] [PATH]

					    -p, --port PORT                  ポートを使う (省略値: 9292)
					    -t, --theme THEME                テーマを使う (省略値: custom)
					    -h, --help                       このメッセージを表示
				EOD
			end

			it "build" do
				proc { memorack 'build', '-h' }.must_output nil, <<-EOD.cut_indent
					Usage: memorack build [options] [PATH]

					    -o, --output DIRECTORY           出力するディレクトリ (省略値: _site)
					    -t, --theme THEME                テーマを使う (省略値: custom)
					        --url URL                    サイトURL (省略値: )
					        --local                      サイトURLをアウトプットディレクトリにする
					        --prettify                   綺麗なURLになるように生成する
					        --index                      サブディレクトリの index.html を出力する
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
					./404.md
					./config.json
					./css
					./css/2-column.scss
					./css/basic-styles.scss
					./css/styles.scss
					./error.html
					./index.html
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

	describe "build" do
		before do
			@hash = {}
			@hash['basic']		= '9b6d4163c422ff9304ebfec6beacb89e23715fe5'
			@hash['oreilly']	= 'ef118f287e80648235a314980da908f70e982478'
			@theme = 'oreilly'

			@file_lists = <<-EOD.cut_indent
				.
				./css
				./css/2-column.css
				./css/basic-styles.css
				./css/styles.css
				./index.html
				./README.html
			EOD
		end

		it "build" do
			theme  = @theme
			output = '_site'

			chmemo { |name|
				proc { memorack 'build' }.must_output "Build 'content/' -> '#{output}'\n"

				Dir.chdir(output) { |output|
					`find . -print`.must_equal @file_lists
					`git hash-object css/styles.css`.must_equal @hash[theme]+"\n"
				}
			}
		end

		it "build PATH" do
			theme  = @theme
			output = '_site'

			chmemo { |name|
				dirname = 'data'
				File.rename('content', dirname)

				Dir.chdir('..')

				path = File.join(name, dirname)
				proc { memorack 'build', path }.must_output "Build '#{path}' -> '#{output}'\n"

				Dir.chdir(output) { |output|
					`find . -print`.must_equal @file_lists
					`git hash-object css/styles.css`.must_equal @hash[theme]+"\n"
				}
			}
		end

		it "build --output DIRECTORY" do
			theme  = @theme
			output = 'output'

			chmemo { |name|
				proc { memorack 'build', '--output', output }.must_output "Build 'content/' -> '#{output}'\n"

				Dir.chdir(output) { |output|
					`find . -print`.must_equal @file_lists
					`git hash-object css/styles.css`.must_equal @hash[theme]+"\n"
				}
			}
		end

		it "build --theme THEME" do
			theme  = 'basic'
			output = '_site'

			chmemo { |name|
				proc { memorack 'build', '--theme', theme }.must_output "Build 'content/' -> '#{output}'\n"

				Dir.chdir(output) { |output|
					`find . -print`.must_equal @file_lists
					`git hash-object css/styles.css`.must_equal @hash[theme]+"\n"
				}
			}
		end

		it "build --url URL" do
			theme  = @theme
			output = '_site'
			url    = 'http://memo.pow'

			chmemo { |name|
				proc { memorack 'build', '--url', url }.must_output "Build 'content/' -> '#{output}'\n"

				Dir.chdir(output) { |output|
					`find . -print`.must_equal @file_lists
					`git hash-object css/styles.css`.must_equal @hash[theme]+"\n"
					File.read('index.html').must_match %r[<a href="#{url}/README.html">MemoRack について</a>]
				}
			}
		end

		it "build --local" do
			theme  = @theme
			output = '_site'

			chmemo { |name|
				url = 'file://' + File.expand_path(output)

				proc { memorack 'build', '--local' }.must_output "Build 'content/' -> '#{output}'\n"

				Dir.chdir(output) { |output|
					`find . -print`.must_equal @file_lists
					`git hash-object css/styles.css`.must_equal @hash[theme]+"\n"
					File.read('index.html').must_match %r[<a href="#{url}/README.html">MemoRack について</a>]
				}
			}
		end

		it "build --prettify" do
			theme  = @theme
			output = '_site'
			url    = ''

			chmemo { |name|
				proc { memorack 'build', '--prettify' }.must_output "Build 'content/' -> '#{output}'\n"

				Dir.chdir(output) { |output|
					`find . -print`.must_equal <<-EOD.cut_indent
						.
						./css
						./css/2-column.css
						./css/basic-styles.css
						./css/styles.css
						./index.html
						./README
						./README/index.html
					EOD

					`git hash-object css/styles.css`.must_equal @hash[theme]+"\n"
					File.read('index.html').must_match %r[<a href="#{url}/README">MemoRack について</a>]
				}
			}
		end

		it "plugin"

		it "macro" do
			theme  = @theme
			output = '_site'

			chmemo { |name|
				patch 'macro'
				proc { memorack 'build' }.must_output "Build 'content/' -> '#{output}'\n"

				Dir.chdir(output) { |output|
					File.read('index.html').must_match %r[<title>覚書き</title>]
					File.read('README.html').must_match %r[<title>MemoRack について ≫ 覚書き</title>]
				}
			}
		end

		it "git"
	end

	describe "server" do
		include Rack::Test::Methods

		before do
			@cwd = Dir.pwd

			name = 'memo'
			Dir.chdir(@tmpdir)
			proc { memorack 'create', name }.must_output "Created '#{name}'\n"
			Dir.chdir(name)
		end

		def app
			Rack::Builder.parse_file('config.ru').first
		end

		it "server /" do
			get '/'
			last_response.must_be :ok?
			last_response.body.must_match /Powered by <a href="#{MemoRack::HOMEPAGE}"[^>]*>/
			last_response.body.must_match %r[<title>覚書き</title>]
		end

		it "server /README" do
			get '/README'
			last_response.must_be :ok?
			last_response.body.must_match /このディレクトリに markdown 等のメモファイルを作成してください/
			last_response.body.must_match %r[<title>MemoRack について \| 覚書き</title>]
		end

		it "server /404" do
			get '/404'
			last_response.status.must_equal 404
			last_response.body.must_match %r[<div id="content"><h3>Not Found</h3>\s+</div>]
			last_response.body.must_match %r[<title>Error 404 \| 覚書き</title>]
		end

		after do
			Dir.chdir(@cwd)
		end
	end

	after do
		FileUtils.remove_entry_secure @tmpdir
	end
end
