# -*- encoding: utf-8 -*-

require 'memorack/plugin'
require 'memorack/locals'


module MemoRack
	class PageInfo < Locals
		extend Plugin

		attr_accessor :max_lines

		def initialize(path, hash = nil, parent = {}, ifnone = nil)
			super ifnone

			@path = path
			merge!(hash) if hash

			@max_lines = 5
			@parent = parent
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
				n = 1

				until methods.empty?
				 	break unless line = file.gets
					break if parse_end?(line, n)

					methods.each { |key, m|
						v = send(m, line, prev)
						if v
							values[key] = v
							methods.delete(key)
						end
					}

					prev = line
					n += 1
				end
			}

			values[info_list.first]
		end

		# ファイル解析の終了か？
		def parse_end?(line, n)
			max_lines < n
		end

		# git で管理されているか？
		def git?
			@parent[:git]
		end

		# git log で更新日時一覧を取得する
		def log
			unless @log
				@log = []
				return @log unless git?

				begin
					dir, fname = File.split(@path)
					Dir.chdir(dir) { |dir|
						log << File::Stat.new(fname).mtime if `git status` =~ /modified:\s+#{fname}/

						`git log --pretty='%ad' --date iso '#{fname}'`.each_line { |line|
							@log << line
						}
					}
				rescue
				end
			end

			@log
		end

		# 値を Timeクラスに変換する
		def value_to_time(value)
			value = Time.parse(value) if value.kind_of?(String)
			value
		end

		def self.define_keys(*keys, &block)
			block = lambda { |key| values[key] || parse(key) } unless block

			keys.each { |name|
				define_key(name, &block)
			}
		end

		define_keys :title

		# 作成時間・更新時間
		define_keys(:ctime, :mtime) { |key|
			values[key] ||= key == :ctime && value_to_time(log.last)	# log から作成時間を取得
			values[key] ||= key == :mtime && value_to_time(log.first)	# log から更新時間を取得
			values[key] ||= File::Stat.new(@path).send(key)				# なければファイル情報から取得
		}

		# 作成日・更新日
		define_keys(:cdate, :mdate) { |key|
			values[key] ||= self[:"#{key[0]}time"].strftime('%Y-%m-%d')
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
			values[:title] ||= I18n.t @parent[:path_info], scope: [:pages],
											default: File.basename(@path, '.*')
		}
	end

end
