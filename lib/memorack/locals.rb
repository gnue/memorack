# -*- encoding: utf-8 -*-

module MemoRack

class Locals < Hash
	alias :super_has_key? has_key?

	# 値を取出す
	def [](key)
		return super if super_has_key?(key)
		return context[key].call(self, key) if context[key]
		return value(key) if value_method?(key)

		super
	end

	# キーがあるか？
	def has_key?(key)
		return true if super
		return true if context.has_key?(key)
		return true if value_method?(key)

		false
	end

	# マージ
	def merge(hash)
		new_hash = super
		new_hash.context = context.dup
		new_hash
	end

	# コールバック登録用のハッシュ
	def context
		@context ||= {}
	end

	# コールバック登録用のハッシュを代入する（merge用）
	def context=(value)
		@context = value
	end

	# キーにコールバックを登録する
	def define_key(name, &block)
		context[name] = block
	end

	# 値を取出すメソッドがあるか？
	def value_method?(name)
		respond_to?(Locals.value_method(name))
	end

	# 値をメソッドから取出す
	def value(name)
		send(Locals.value_method(name), name)
	end

	# 値を取出すメソッド名
	def self.value_method(name)
		:"value_#{name}"
	end

	# キーにメソッドを登録する
	def self.define_key(name, &block)
		define_method(value_method(name), &block)
	end
end

end
