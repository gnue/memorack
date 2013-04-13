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

			FileUtils.mkpath(options[:output])

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

			copy_statics(@root, options)
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

		# 静的ファイルのコピー
		def copy_statics(dir, options)
			output = File.expand_path(options[:output])

			Dir.chdir(dir) { |dir|
				Dir.glob('**/*') { |path|
					next if File.directory?(path)
					next if @templates.include?(path)

					to = File.join(output, path)
					FileUtils.mkpath(File.dirname(to))
					FileUtils.copy_entry(path, to)
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
