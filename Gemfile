source :rubygems

gem 'mustache'
gem 'json'
gem 'sass'
gem 'directory_watcher'

group :redcarpet do
	gem 'redcarpet'	# Object.send(:remove_const, :RedcarpetCompat) しないと Tilt で古いエンジンが使用されてしまう
end

group :kramdown do
	gem 'kramdown'
end

group :maruku do
	gem 'maruku'	# - が使えない, 日本語リンクのメニューが作成できない
end

group :rdiscount do
	gem 'rdiscount'	# 日本語リンクが NG
end

group :bluecloth do
	gem 'bluecloth'	# 日本語リンクが NG
end
