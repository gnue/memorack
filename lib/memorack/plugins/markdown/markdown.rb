# -*- encoding: utf-8 -*-

require 'memorack/pageinfo'


module MemoRack

	class PageInfoMarkdown < PageInfo
		# ファイル拡張子
		def self.extnames
			['md', 'mkd', 'markdown']
		end

		def accept_title(line, prev = nil)
			case line
			when /^(\#{1,6}?)\s+(.+)$/
				level = $1.length
				headline = $2.gsub(/\#+\s*$/, '').strip
				return headline
			when /^\s*([=\-])+\s*$/
				return nil unless prev
		
				prev = prev.strip
				unless prev.empty?
					level = ($1 == '=') ? 1 : 2
					return prev
				end
			end
		end
	end

end
