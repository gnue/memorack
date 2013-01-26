# coding: utf-8

$LOAD_PATH.unshift('./lib')

require 'memorack'

run MemoRack::MemoApp.new(nil, theme: 'custom')
