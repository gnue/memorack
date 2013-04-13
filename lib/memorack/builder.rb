# -*- encoding: utf-8 -*-

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

			output = options[:output]
			FileUtils.mkpath(output)

			@contents = contents(options)

			content_write(:index, options) { |template|
				render_with_mustache template, :markdown
			}

			@contents.files.each { |file|
				yield(file) if block_given?

				content_write(file[:path], options) { |template|
					render_content({}, template)
				}
			}
		end

		# コンテンツをファイルに出力する
		def content_write(template, options)
			begin
				content = yield(template)
				return unless content

				path = template
				path = path.sub(/\.[^.]*$/, '') if path.kind_of?(String)

				to = path.to_s + options[:suffix]
				to = File.join(options[:output], to)

				FileUtils.mkpath(File.dirname(to))
				File.write(to, content)
			rescue
			end
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
