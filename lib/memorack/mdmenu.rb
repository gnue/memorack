#!/usr/bin/env ruby
# coding: UTF-8

=begin

= 

Authors::   GNUE(鵺)
Version::   1.0 2011-10-25 gnue
Copyright:: Copyright (C) gnue, 2011. All rights reserved.
License::   MIT ライセンスに準拠


== 使い方


== 開発履歴

* 1.0 2011-10-25
  * とりあえず作ってみた

=end


require 'optparse'
require 'uri'


# ruby 1.9系対応
if RUBY_VERSION >= '1.9.0'
	class << File
		alias :join_without_for_encoding_filter :join

		def join_with_for_encoding_filter(*args)
			join_without_for_encoding_filter(*args).force_encoding(Encoding.default_external)
		end

		alias :join :join_with_for_encoding_filter
	end
end


class MdMenu
	DEFAULT_FORMATS = {
		'markdown'	=> ['txt', 'md', 'markdown'],
		'textile'	=> ['tt'],
		'wiki'		=> ['wiki'],
		'json'		=> ['json'],
		'html'		=> ['html', 'htm']
	}

	@@extentions = {}

	DEFAULT_FORMATS.each { |name, extentions|
		extentions.each { |value|
			@@extentions[value] = name
		}
	}

	def initialize(config)
		@config = config
		@file = config[:file]
		@links = analyze(@file)
		@files = []
		@extentions = @@extentions.clone
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
			link = @config[:prefix].to_s + (@config[:uri_escape] ? URI.escape(path) : path)
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
	def generate(outfile = @file)
		len = @files.length

		if 0 < len
			outfile = nil if outfile && outfile.kind_of?(String) && File.exist?(outfile) && ! @config[:update]

			stdout(outfile, 'a') {
				prefix = @config[:prefix]
				dir = nil
				dirs = []

				@files.each { |item|
					title = File.basename(item[:path], '.*')
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

		$stderr.print message, "\n" if message

		outfile
	end
end


if __FILE__ == $0
	# コマンド引数の解析
	config = {}

	OptionParser.new { |opts|
		opts.banner = "Usage: #{opts.program_name} [-f FILE] [-u] [-e] [--prefix PREFIX] DIRECTORY… "

		opts.on('-f FILE', 'menu file')						{ |v| config[:file] = v }
		opts.on('-u', 'file update(default is dry-run)')	{ config[:update] = true }
		opts.on('-e', 'URI escape')							{ config[:uri_escape] = true }
		opts.on('-p PREFIX', '--prefix PREFIX', 'link prefix') { |v| config[:prefix] = v }
		opts.on('-h', '--help')								{ abort opts.help }
		opts.parse!(ARGV)
	}

	ARGV.push '.' if ARGV.length == 0

	mdmenu = MdMenu.new(config)

	ARGV.each { |dir| mdmenu.collection(dir) }
	mdmenu.generate
end
