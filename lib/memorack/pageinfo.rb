# -*- encoding: utf-8 -*-

require 'memorack/plugin'
require 'memorack/locals'


module MemoRack
	class PageInfo < Locals
		extend Plugin

		def initialize(path, hash = nil, ifnone = nil)
			super ifnone

			@path = path
			merge!(hash) if hash
		end

		def values
			@values ||= {}
		end

		# ファイルを解析
		def parse(*info_list)
			methods = {}

			info_list.each { |info|
				m = "accept_#{info}"
				methods[info] = m if respond_to?(m)
			}

			open(@path, 'r') { |file|
				prev = nil

				(1 .. 5).each { |i|
					break if methods.empty?
				 	break unless line = file.gets

					methods.each { |key, m|
						v = send(m, line, prev)
						if v
							values[key] = v
							methods.delete(key)
						end
					}

					prev = line
				}
			}

			values[info_list.first]
		end

		def self.define_keys(*keys, &block)
			block = lambda { |key| values[key] || parse(key) } unless block

			keys.each { |name|
				define_key(name, &block)
			}
		end

		define_keys :title

		# 作成日・更新日
		define_keys(:ctime, :mtime) { |key|
			values[key] ||= File::Stat.new(@path).send(key)
		}
	end

	# デフォルト用
	class PageInfoDefault < PageInfo
		# 優先順位
		def self.priority
			-1
		end

		def self.member?(key, ext = nil)
			ext != nil
		end

		define_key(:title) { |key|
			values[:title] ||= File.basename(@path, '.*')
		}
	end

end
