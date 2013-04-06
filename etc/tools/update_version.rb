def update_version(path)
	version = `git describe --dirty 2>/dev/null`.chomp
	version = `git describe --tags --dirty`.chomp if version.empty?
	version[0, 1] = '' if version =~ /^v[0-9]/
	version.gsub!(/-([a-z0-9]+(-dirty)?)$/) { |m| "(#{$1})" }

	begin
		return if version == open(path).read.chomp
		return if version.empty?
	rescue
	end

	open(path, 'w') { |f| f.puts version }
end

update_version 'VERSION'
