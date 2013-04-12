# -*- encoding: utf-8 -*-

require 'pathname'
require 'rubygems'

require 'memorack/core'

module MemoRack
	class Builder < Core

		def generate(options = {})
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
			contents.generate(StringIO.new).string
		end

	end
end
