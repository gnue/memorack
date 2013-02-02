# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'memorack/version'

Gem::Specification.new do |gem|
  gem.name          = "memorack"
  gem.version       = MemoRack::VERSION
  gem.authors       = ["gnue"]
  gem.email         = ["gnue@so-kukan.com"]
  gem.description   = %q{Simple Memo Rack Server}
  gem.summary       = %q{Simple Memo Rack Server}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.required_ruby_version = '>= 1.9.0'

  gem.add_dependency('rack')
  gem.add_dependency('tilt')
  gem.add_dependency('mustache')
  gem.add_dependency('redcarpet', '>= 2.0.0')
  gem.add_dependency('json')
  gem.add_dependency('sass')
end
