# -*- encoding: utf-8 -*-

require 'set'
require 'fileutils'
require 'pathname'
require 'rubygems'

require 'memorack/core'

module MemoRack
	class Builder < Core

		DEFAULT_BUILD_OPTIONS = {
			output:		'site',
			prefix:		'',
			suffix:		'.html',
			uri_escape:	true,
		}

		def generate(options = {})
			options = DEFAULT_BUILD_OPTIONS.merge(options)
			options[:prefix] = File.join(options[:url], '') + options[:prefix] unless options[:url].empty?

			output = File.expand_path(options[:output])
			FileUtils.mkpath(output)

			@contents = contents(options)
			@templates = Set.new @contents.files.collect { |file| file[:path] }

			content_write(:index, options[:suffix], options) { |template|
				render_with_mustache template, :markdown
			}

			@templates.each { |path|
				yield(path) if block_given?

				content_write(path, options[:suffix], options) { |template|
					render_content({}, template)
				}
			}

			css_exts = Set.new ['css', *@css]

			@public.each { |path|
				ext = split_extname(path)[1]

				if css_exts.include?(ext)
					content_write(path, '.css', options) { |template|
						content = render_css({}, template)
					}
				end
			}

			copy_statics(@root, output)
		end

		# コンテンツをファイルに出力する
		def content_write(template, suffix, options)
			begin
				content = yield(template)
				return unless content

				path = template
				path = path.sub(/\.[^.]*$/, '') if path.kind_of?(String)

				to = path.to_s + suffix
				to = File.join(options[:output], to)

				FileUtils.mkpath(File.dirname(to))
				File.write(to, content)
			rescue
			end
		end

		# ファイルをコピーする
		def copy_file(path, output)
			return if File.directory?(path)
			return if @templates.include?(path)

			to = File.join(output, path)
			FileUtils.mkpath(File.dirname(to))
			FileUtils.copy_entry(path, to)
		end

		# 静的ファイルのコピー
		def copy_statics(dir, output)
			Dir.chdir(dir) { |dir|
				Dir.glob('**/*') { |path|
					copy_file(path, output)
				}
			}
		end

		#### テンプレート

		# インデックスを作成
		template :index do
			begin
				render :markdown, 'index.md', {views: @themes}
			rescue
				''
			end
		end

		# メニューを作成
		template :menu do
			@contents.generate(StringIO.new).string
		end

	end
end
