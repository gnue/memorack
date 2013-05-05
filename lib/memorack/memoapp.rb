# -*- encoding: utf-8 -*-

require 'pathname'
require 'rubygems'
require 'rack'
require 'uri'

require 'memorack/core'
require 'memorack/pageinfo'

module MemoRack
	class MemoApp < Core

		def initialize(app, options={})
			super(options)

			@app = app
			define_statics(@root, *@themes)

			# ファイル監視を行う
			watcher(@root, @directory_watcher) if @directory_watcher
		end

		def call(env)
			content_type = 'text/html'

			path_info = unescape_path_info(env)

			case path_info
			when '/'
				content = render_with_mustache :index, :markdown
			when /\.css$/
				result = pass(env, @statics)
				return result unless result.first == 404

				begin
					content_type = 'text/css'
					content = render_css(path_info)
				rescue Errno::ENOENT => e
					return error(env, 404)
				end
			else
				locals = {env: env, path_info: path_info}
				content ||= render_content(path_info, locals)
				content ||= render_page(path_info, locals)
			end

			return [200, {'Content-Type' => content_type}, [content.to_s]] if content

			pass(env) { |env, code|
				error(env, code)
			} 
		end

		# 静的ファイルの参照先を定義する
		def define_statics(*args)
			@statics = [] unless @statics

			@statics |= args.collect { |root| Rack::File.new(root) }
		end

		# PATH_INFO を unescape して取出す
		def unescape_path_info(env)
			path_info = URI.unescape(env['PATH_INFO'])
			path_info.force_encoding('UTF-8')
		end

		# リダイレクト
		def redirect(url, code = 301)
			# 301 = 恒久的, 302 = 一時的, 303, 410
			[code, {'Content-Type' => 'text/html', 'Location' => url}, ['Redirect: ', url]]
		end

		# 次のアプリにパスする
		def pass(env, apps = @statics + [@app])
			apps.each { |app|
				next unless app

				result =  app.call(env)
				return result unless result.first == 404
			}

			return yield(env, 404) if block_given?

			error(env, 404, 'File not found: ')
		end

		# エラー
		def error(env, code, body = nil, content_type = 'text/plain; charset=utf-8')
			path_info = unescape_path_info(env)

			if body
				body = [body.to_s, path_info] unless body.kind_of?(Array)
			else
				fullpath = file_search("/#{code}", {views: @themes})
				ext = split_extname(fullpath)[1]
				locals = {env: env, path_info: path_info, page: {name: "Error #{code}"}}

				if ext && Tilt.registered?(ext)
					template = Pathname.new(fullpath)
				else
					template = "Error #{code}: #{path_info}"
					ext = nil
				end

				content = render_with_mustache template, ext, {mustache: 'error.html'}, locals

				if content
					content_type = 'text/html'
					body = [content.to_s]
				else
					body = ["Error #{code}: ", path_info]
				end
			end

			[code, {'Content-Type' => content_type, }, body]
		end

		# ファイル監視を行う
		def watcher(path = '.', interval = 1.0)
			require 'directory_watcher'

			interval = 1.0 if interval == true # 旧バージョンとの互換性のため

			dw = DirectoryWatcher.new path, :pre_load => true
			dw.interval = interval
			dw.stable = 2
			dw.glob = '**/*'
			dw.add_observer { |*args|
				t = Time.now.strftime("%Y-%m-%d %H:%M:%S")
				puts "[#{t}] regeneration: #{args.size} files changed"

				@menu = nil
			}

			dw.start
		end


		#### テンプレート

		# インデックスを作成
		template :index do
			begin
				render :markdown, 'index.md', {views: @themes}
			rescue
				''
			end
		end

		# メニューを作成
		template :menu do
			contents.generate(StringIO.new, &method(:content_name).to_proc).string
		end

	end
end
