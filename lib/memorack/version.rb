module MemoRack
	HOMEPAGE = 'https://github.com/gnue/memorack'

	begin
		dir = File.expand_path('../../..', __FILE__)
		version  = File.read(File.join(dir, 'VERSION')).chomp
		revision = File.read(File.join(dir, 'REVISION')).chomp.split('/')

		case revision.first
		when /^#{version}(-|$)/
			ver, rev = revision
		else
			version += 'dev'
			ver = version

			revision.delete('')
			rev = revision.join('/')
		end

	rescue
		ver = version
	end

	VERSION = version
	LONG_VERSION = ver + (rev ? "(#{rev})" : '')
end
