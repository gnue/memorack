require 'minitest/spec'
require 'minitest/autorun'
require 'rack/test'

begin
	require 'turn'

	Turn.config.format = :progress
rescue LoadError
end
