require 'minitest/spec'
require 'minitest/autorun'

begin
	require 'turn'

	Turn.config.format = :progress
rescue LoadError
end
