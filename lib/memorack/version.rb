module MemoRack
	LONG_VERSION = File.read(File.expand_path('../../../VERSION', __FILE__)).chomp
	LONG_VERSION.scan(/^([0-9.]+)/) { |match| VERSION = match[0] }

	HOMEPAGE = 'https://github.com/gnue/memorack'
end
