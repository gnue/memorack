require 'minitest/autorun'
require 'minitest/spec'
require 'rack/test'

begin
	require 'turn'

	Turn.config.format = :progress
rescue LoadError
end
