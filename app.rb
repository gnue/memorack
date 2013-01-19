# coding: utf-8

$LOAD_PATH.unshift('./lib')

require 'rubygems'
#require 'rdiscount'
#require 'bluecloth'
require 'kramdown'
#require 'redcarpet'
#require 'maruku'
require 'sinatra'
require 'mdmenu'
require 'sinatra-mustache'
require 'tilt-template-fix'
require 'json'
require 'sass'


def read_json(path)
	begin
		data = File.read(path)
		JSON.parse(data)
	rescue Exception => e
		abort e.to_s
	end
end


# レイアウトに mustache を適用してテンプレートエンジンでレンダリングする
def render_with_mustache(template, engine = :markdown, options = {}, locals = {})
	begin
		menu = markdown :menu, options
		options[:tables] = true
		content = render engine, template, options

		locals[:menu]			||= menu.force_encoding('UTF-8')
		locals[:content]		||= content.force_encoding('UTF-8')
		locals[:title]			||= settings.config['title'] || 'memo'
		locals[:page]			||= {}

		locals[:page][:title]	||= locals[:title] if template == :index
		locals[:page][:title]	||= [File.basename(template.to_s), locals[:title]].join(' | ')

		mustache :layout, {views: settings.templates_folder}, locals
	rescue => e
		e.to_s
	end
end


def split_extname(path)
	return [$1, $2] if /^(.+)\.([^.]+)/ =~ path

	[path]
end


set :templates_folder, File.expand_path('templates', settings.root)
set :config, read_json(File.expand_path('config.json', settings.root)) || {}


### レスポンス

get '/' do
	render_with_mustache :index
end

get '/*.css' do |name|
	begin
		scss name.to_sym, {views: settings.public_folder}
	rescue => e
		e.to_s
	end
end

get '/*' do
	path, ext = split_extname(params[:splat].first)

	pass unless Tilt.registered?(ext)
	render_with_mustache path.to_sym, ext
end


get '/*' do
	path, ext = split_extname(params[:splat].first)

	content_type ext
	send_file File.join(settings.views, "#{path}.#{ext}")
end


### テンプレート

template :index do
	''
end

template :menu do
	mdmenu = MdMenu.new({prefix: '/', uri_escape: true})
	Dir.chdir('views') { |path| mdmenu.collection('.') }
	mdmenu.generate(StringIO.new).string
end

