# coding: utf-8

$LOAD_PATH.unshift('./lib')

require 'rack-memo'

run MemoApp.new(nil, root: 'views/', theme: 'themes/oreilly/', markdown: 'kramdown')
