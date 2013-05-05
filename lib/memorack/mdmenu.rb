#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

require 'optparse'
require 'uri'


module MemoRack

class MdMenu
	URI_UNSAFE = /[^\-_.!~*'a-zA-Z\d;\/?:@&=+$,\[\]]/

	DEFAULT_FORMATS = {
		'markdown'	=> ['txt', 'md', 'markdown'],
		'textile'	=> ['tt'],
		'wiki'		=> ['wiki'],
		'json'		=> ['json'],
		'html'		=> ['html', 'htm']
	}

	attr_reader :files

	def initialize(config)
		@config = config
		@file = config[:file]
		@links = analyze(@file)
		@files = []
		@extentions = {}

		regFormats(config[:formats] || DEFAULT_FORMATS)
	end

	# フォーマット・ハッシュからファイル拡張子を登録する
	def regFormats(formats)
		formats.each { |name, extentions|
			regFormat(name, extentions)
		}
	end

	# フォーマットとファイル拡張子を登録する
	def regFormat(name, extentions)
		extentions.each { |value|
			@extentions[value] = name
		}
	end

	# Markdownファイルを解析してリンクを取出す
	def analyze(path)
		links = []

		if path && File.exist?(path) then
			open(path) { |f|
				while line = f.gets()
					case line
					when /\[.+\]\s*\(([^()]+)\)/
						# インライン・リンク
						links << $1
					when /\[.+\]:\s*([^\s]+)/
						# 参照リンク
						links << $1
					end
				end
			}
		end

		return links
	end

	# 追加されたファイルを集める
	def collection(dir)
		# 拡張子
		exts = @extentions.keys.join(',')
		# 検索パターン
		pattern = File.join(dir, "**/*.{#{exts}}");
		pattern.gsub!(/^\.\//, '')

		Dir.glob(pattern) { |path|
			link = @config[:prefix].to_s + (@config[:uri_escape] ? URI.escape(path, URI_UNSAFE) : path)
			link = link.sub(/\.[^.]*$/, '') + @config[:suffix] if @config[:suffix]
			@files << {:link => link, :path => path} if ! @links.member?(link)
		}
	end

	# 標準出力を切換える
	def stdout(path, mode = 'r', perm = 0666)
		curr = $stdout
		f = nil

		begin
			if path.kind_of?(String)
				$stdout = f = File.open(path, mode, perm)
			elsif path
				$stdout = path
			end

			yield
		ensure
			f.close if f
			$stdout = curr
		end
	end

	# ディレクトリが違うときにサブディレクトリを引数に実行する
	def each_subdir(d, dir = nil, dirs = [])
		return [dir, dirs] if d == dir

		prefix = @config[:prefix]

		d = File.join(d, '')
		d.gsub!(/^#{prefix}/, '') if prefix
		ds = d.scan(/[^\/]+/)
		ds.delete('.')

		ds.each_with_index { |name, i|
			next if name == dirs[i]

			name = URI.unescape(name) if @config[:uri_escape]
			yield(name, i)
		}

		[d, ds]
	end

	# 新規リンクを追加する
	def generate(outfile = @file, &block)
		len = @files.length

		if 0 < len
			outfile = nil if outfile && outfile.kind_of?(String) && File.exist?(outfile) && ! @config[:update]
			block = lambda { |path| File.basename(path, '.*') } unless block

			stdout(outfile, 'a') {
				prefix = @config[:prefix]
				dir = nil
				dirs = []

				@files.each { |item|
					title = block.call(item[:path])
					link = item[:link]

					dir, dirs = each_subdir(File.dirname(link), dir, dirs) { |name, i|
						print '  ' * i + "- #{name}\n"
					}

					print '  ' * dirs.size + "- [#{title}](#{link})\n"
				}
			}

			if outfile then
				# update
				message = "append #{len} links"
			else
				# dry-run
				message = "found #{len} links (can update with -u option)"
			end
		else
			message = "not found"
		end

		$stderr.print message, "\n" if message && @config[:verbose]

		outfile
	end
end

end


if __FILE__ == $0
	# コマンド引数の解析
	config = {:verbose => true}

	OptionParser.new { |opts|
		opts.banner = "Usage: #{opts.program_name} [-f FILE] [-u] [-e] [--prefix PREFIX] [--suffix SUFFIX] DIRECTORY… "

		opts.on('-f FILE', 'menu file')						{ |v| config[:file] = v }
		opts.on('-u', 'file update(default is dry-run)')	{ config[:update] = true }
		opts.on('-e', 'URI escape')							{ config[:uri_escape] = true }
		opts.on('-p PREFIX', '--prefix PREFIX', 'link prefix') { |v| config[:prefix] = v }
		opts.on('-s SUFFIX', '--suffix SUFFIX', 'link suffix') { |v| config[:suffix] = v }
		opts.on('-h', '--help')								{ abort opts.help }
		opts.parse!(ARGV)
	}

	ARGV.push '.' if ARGV.length == 0

	mdmenu = MemoRack::MdMenu.new(config)

	ARGV.each { |dir| mdmenu.collection(dir) }
	mdmenu.generate
end
