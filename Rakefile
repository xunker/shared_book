require 'rubygems'
gem 'hoe', '>= 2.1.0'
gem 'multipart-post', '>= 1.0.1'
require 'hoe'
require 'fileutils'
require './lib/shared_book'

VERSION = "0.1.0"

Hoe.plugin :newgem

$hoe = Hoe.spec 'shared_book' do
  self.developer 'Matthew Nielsen', 'xunker@pyxidis.org'
end

require 'newgem/tasks'
Dir['tasks/**/*.rake'].each { |t| load t }

task :default => :spec