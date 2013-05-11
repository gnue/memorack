# -*- encoding: utf-8 -*-

require 'memorack/pageinfo'
require 'time'

require 'rubygems'
require 'org-ruby'


module MemoRack

	class PageInfoOrg < PageInfo
		# ファイル拡張子
		def self.extnames
			['org']
		end

		def self.org_keys(*keys, &block)
			define_keys *keys

			keys.each { |name|
				block = lambda { |line, prev = nil| org_info(name, line) }
				define_method("accept_#{name}", &block)
			}
		end

		# ファイル解析の終了か？
		def parse_end?(line, n)
			line !~ /^\#/
		end

		def org_info(name, line)
			name = name.to_s.upcase

			if line =~ /^\#\+#{name}:\s*(.+)$/
				$1.strip
			end
		end

		def accept_date(line, prev = nil)
			value = org_info(:date, line)
			value = Time.parse(value) if value
			value
		end

		# 作成日
		define_key(:ctime) { |key|
			values[key] ||= parse(:date) || File::Stat.new(@path).ctime
		}

		org_keys :title, :author, :email, :language, :description
	end

end
