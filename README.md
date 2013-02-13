# MemoRack

Rack Application for markdown memo

## Installation

Add this line to your application's Gemfile:

    gem 'memorack'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install memorack

## Usage

	$ memorack create PATH				# Generate template folder
	$ memorack server PATH				# Instant Server

Standard startup

	$ memorack create memo
	$ cd memo
	(Customizing...)
	$ rackup

Instant server

	$ mkdir content
	$ echo '# Hello World' > content/hello.md
	(Customizing...)
	$ memorack server content

OS X (Pow + powder)

	$ memorack create memo
	$ cd memo
	(Customizing...)
	$ powder link
	$ open http://memo.dev/

* [Pow: Zero-configuration Rack server for Mac OS X](http://pow.cx)
* `gem install powder`

## Directory

Template

	.
	├── .gitignore					-- for git
	├── .powenv						-- for pow + rbenv
	├── Gemfile						-- `bundle install`
	├── config.ru					-- for rack application
	├── content						-- Content directory for memo
	│   └── README.md				-- Sample file(remove it)
	└── themes
	    └── custom					-- Default theme
	        ├── config.json			-- Configuration
	        └── index.md			-- Description(Show by top page)

## TODO

* Test program

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
