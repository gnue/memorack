# -*- encoding: utf-8 -*-


module MemoRack

	Core.app.instance_eval do
		@formats.each { |format|
			require_plugin(File.join('formats', format))
		}
	end

end
