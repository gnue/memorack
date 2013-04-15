def update_revision(path = 'REVISION')
	rev = `git describe --dirty --long 2>/dev/null`.chomp
	rev = `git describe --dirty --long --tags --always`.chomp if rev.empty?
	rev.gsub!(/^v([0-9])/, '\1')
	rev.gsub!(/(^|-)([a-z0-9]+(-dirty)?)$/, '/\2')
	rev.gsub!(/^([0-9.]+)-0\//, '\1/')

	return if File.exists?(path) && rev == open(path).read.chomp

	open(path, 'w') { |f| f.puts rev }
end


update_revision
