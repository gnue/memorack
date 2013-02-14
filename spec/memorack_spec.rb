# -*- encoding: utf-8 -*-

require File.expand_path('../spec_helper', __FILE__)
require 'memorack'
require 'memorack/cli'


describe MemoRack do
	# MemoRack::CLI.run を呼出す
	def memorack(*argv)
		begin
			MemoRack::CLI.run(argv)
		rescue SystemExit => err
			@abort = err.inspect
		end
	end

	before do
		require 'tmpdir'
		@tmpdir = Dir.mktmpdir
	end

	describe "create" do
		it "create"
	end

	describe "theme" do
		it "theme"
	end

	describe "server" do
		it "server"
	end

	after do
		FileUtils.remove_entry_secure @tmpdir
	end
end
