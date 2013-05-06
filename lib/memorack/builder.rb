# -*- encoding: utf-8 -*-

require 'set'
require 'fileutils'
require 'pathname'
require 'rubygems'

require 'memorack/core'

module MemoRack
	class Builder < Core

		DEFAULT_BUILD_OPTIONS = {
			output:		'_site',
			prefix:		'/',
			suffix:		'.html',
			uri_escape:	true,
		}

		DEFAULT_KEEPS = ['.git', '.hg', '.svn', '.csv']

		def generate(options = {}, &callback)
			options = DEFAULT_BUILD_OPTIONS.merge(options)
			keeps = options[:keep] || @options[:keeps] || DEFAULT_KEEPS

			url = @site[:url]
			options[:prefix] = File.join(url, options[:prefix]) unless url.empty?
			@suffix = options[:suffix]

			output = File.expand_path(options[:output])
			dir_init(output, keeps)

			@contents = contents(options)
			@templates = Set.new @contents.files.collect { |file| file[:path] }

			# トップページを作成する
			content_write(:index, '.html', output) { |template|
				render_with_mustache template, :markdown
			}

			suffix = options[:suffix]
			suffix = '/index.html' if ['', '/'].member?(suffix)

			# 固定ページのレンダリングを行う
			pages.each { |path_info, path|
				callback.call(path_info) if callback

				content_write(path_info, suffix, output) { |template|
					render_page template, {path_info: path_info}
				}
			}

			# コンテンツのレンダリングを行う
			@templates.each { |path|
				callback.call(path) if callback

				content_write(path, suffix, output) { |template|
					render_content template, {path_info: path}, nil
				}
			}

			# テーマの公開ファイルをコピー
			copy_public(@themes, output, &callback)

			# 静的ファイルをコピーする
			copy_statics(@root, output, &callback)
		end

		# ディレクトリを初期化する
		def dir_init(dir, keeps = [])
			if Dir.exists?(dir)
				Dir.glob(File.join(dir, '*'), File::FNM_DOTMATCH) { |path|
					fname = File.basename(path)

					next if /^\.{1,2}$/ =~ fname
					next if keeps.member?(fname)

					FileUtils.remove_entry_secure(path)
				}
			else
				FileUtils.mkpath(dir)
			end
		end

		# テーマから公開用のファイルを収集する
		def public_files
			unless @public_files
				@public_files = Set.new

				@public.each { |path_info|
					if path_info[-1] == '/'
						@themes.each { |theme|
							if Dir.exists?(File.join(theme, path_info))
								Dir.chdir(theme) { |dir|
									@public_files += Dir.glob(File.join(path_info, '**/*'))
								}
							end
						}
					else
						@public_files << path_info
					end
				}
			end

			@public_files
		end

		# コンテンツをファイルに出力する
		def content_write(template, suffix, output)
			begin
				content = yield(template)
				return unless content

				path = template
				path = path.sub(/\.[^.]*$/, '') if path.kind_of?(String)

				to = path.to_s + suffix
				to = File.join(output, to)

				FileUtils.mkpath(File.dirname(to))
				File.write(to, content)
			rescue
			end
		end

		# ファイルをコピーする
		def copy_file(path, output, &callback)
			return if File.directory?(path)
			return if @templates.include?(path)

			callback.call(path) if callback

			if output.kind_of?(Array)
				to = File.join(*output)
			else
				to = File.join(output, path)
			end

			FileUtils.mkpath(File.dirname(to))
			FileUtils.copy_entry(path, to)
		end

		# 静的ファイルをコピーする
		def copy_statics(dir, output, &callback)
			Dir.chdir(dir) { |dir|
				Dir.glob('**/*') { |path|
					copy_file(path, output, &callback)
				}
			}
		end

		# テーマの公開ファイルをコピーする
		def copy_public(views, output, &callback)
			public_files.each { |path_info|
				callback.call(path_info) if callback

				ext = split_extname(path_info)[1]

				if css_exts.include?(ext)
					content_write(path_info, '.css', output) { |template|
						content = render_css(template)
					}
				else
					fullpath = file_search(path_info, {views: views}, nil)
					copy_file(fullpath, [output, path_info]) if fullpath
				end
			}
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
			@contents.generate(StringIO.new, &method(:content_name).to_proc).string
		end

	end
end
