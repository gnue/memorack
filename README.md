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
	$ memorack theme					# Show theme list
	$ memorack theme THEME				# Show theme info
	$ memorack theme -c THEME			# Copy theme
	$ memorack server [PATH]			# Instant Server
	$ memorack build  [PATH]			# Build static site

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

Build static site

	$ memorack create memo
	$ cd memo
	(Customizing...)
	$ memorack build --url http://foo.bar.baz
	Build 'content/' -> '_site'

## Directory

Template

	.
	├── .gitignore                 -- for git
	├── .powenv                    -- for pow + rbenv
	├── Gemfile                    -- `bundle install`
	├── config.ru                  -- for rack application
	├── content/                   -- Content directory for memo
	│   └── README.md              -- Sample file(remove it)
	├── plugins/					-- Plugins directory
	└── themes/
	    └── custom/                -- Default theme
	        ├── config.json        -- Configuration
	        ├── index.md           -- Description(Show by top page)
	        ├── locales/			-- Locales directory
	        ├── macro.yml			-- Macro
	        └── pages/				-- Pages directory

## Customization

### Layout

`index.html` is mustache template

	$ cd themes/custom
	$ memorack theme -c basic/index.html
	Created 'index.html'
	(Edit 'index.html'...)

Directory

	└── themes/
	    └── custom/
	        ├── config.json
	        ├── index.html         <-- Edit layout
	        └── index.md

### Logo

	└── themes/
	    └── custom/
	        ├── config.json        <-- Add "logo": "/img/logo.png"
	        ├── img/
	        │   └── logo.png       <-- Add image file
	        ├── index.html         <-- Add <img id="logo" src="{{logo}}" />
	        └── index.md

### Syntax highlighting

Download [highlight.js](http://softwaremaniacs.org/soft/highlight/en/)

	└── themes/
	    └── custom/
	        ├── config.json
	        ├── highlight.js       <-- `unzip highlight.zip`
	        ├── index.html         <-- Add code
	        └── index.md

Add code to `index.html`

	<link rel="stylesheet" href="{{site.url}}/highlight.js/styles/default.css">
	<script src="{{site.url}}/highlight.js/highlight.pack.js"></script>
	<script>hljs.initHighlightingOnLoad();</script>

### org-mode

Install

	$ gem install org-ruby

Edit `config.json`

	{
		"formats":		["markdown", "org"],
		...
	}

#### mustache variables

Basic variables -- `{{VAR}}`

* `site.url`
* `title`
* `page.title`
* `app.name`
* `app.version`
* `app.url`
* other variable in config.json

Special variables -- `{{{VAR}}}`

* `__menu__`
* `__content__`

## TODO

* Template comments translate english
* Add customizing tips
* More test program
* Generate EPUB3

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
