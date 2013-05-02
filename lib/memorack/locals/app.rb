# -*- encoding: utf-8 -*-

require 'memorack/locals'


module MemoRack

	class AppLocals < Locals

		define_key(:name)		{ |key| MemoRack::name }
		define_key(:version)	{ |key| MemoRack::VERSION }
		define_key(:url)		{ |key| MemoRack::HOMEPAGE }

	end

end
