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

			output = options[:output]
			FileUtils.mkpath(output)

			@contents = contents(options)

			@contents.files.each { |file|
				path = file[:path]
				content = render_content({}, path)
				next unless content

				yield(file) if block_given?

				begin
					to = path.sub(/\.[^.]*$/, '') + options[:suffix]
					to = File.join(output, to)
					FileUtils.mkpath(File.dirname(to))
					File.write(to, content)
				rescue
				end
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
