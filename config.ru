# coding: utf-8

$LOAD_PATH.unshift('./lib')

require 'rack-memo'

run MemoRack::MemoApp.new(nil, theme: 'custom')
