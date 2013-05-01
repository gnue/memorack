# -*- encoding: utf-8 -*-

module MemoRack

class Locals < Hash
	alias :super_has_key? has_key?

	@@context = {}

	def [](key)
		return super if super_has_key?(key)
		return context[key].call(self, key) if context[key]
		return instance_exec(key, &@@context[key]) if @@context[key]

		super
	end

	def has_key?(key)
		return true if context.has_key?(key)
		return true if @@context.has_key?(key)
		super
	end

	def merge(hash)
		new_hash = super
		new_hash.context = context.dup
		new_hash
	end

	def context
		@context ||= {}
	end

	def context=(value)
		@context = value
	end

	def define_key(name, &block)
		context[name] = block
	end

	def self.define_key(name, &block)
		@@context[name] = block
	end
end

end
