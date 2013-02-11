def update_version(path)
	version = `git describe --tags --dirty`.chomp
	version.gsub!(/-([a-z0-9]+(-dirty)?)$/) { |m| "(#{$1})" }

	begin
		return if version == open(path).read.chomp
	rescue
	end

	open(path, 'w') { |f| f.puts version }
end

update_version 'VERSION'
