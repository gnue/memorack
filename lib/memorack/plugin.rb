# -*- encoding: utf-8 -*-

require 'set'


module MemoRack
	module Plugin

		## extend Plugin で使用する

		# サブクラスが追加されたらプラグインに登録する
		def inherited(subclass)
			plugins << subclass
		end

		# プラグイン一覧
		def plugins
			@plugins ||= SortedSet.new
		end

		# 優先順位
		def priority
			1
		end

		# プラグインの優先順位を比較する
		def <=>(other)
			r = - (self.priority <=> other.priority)
			return r unless r == 0

			self.to_s <=> other.to_s
		end

		def member?(key, ext = nil)
			extnames.member?(ext)
		end

		def extnames
			[]
		end

		# ファイル拡張子からプラグインをみつける
		def [](key)
			ext = File.extname(key)[1..-1]

			plugins.each { |plugin|
				return plugin if plugin.member?(key, ext)
			}

			nil
		end

	end
end
