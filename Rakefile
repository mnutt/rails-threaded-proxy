# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://guides.rubygems.org/specification-reference/ for more options
  gem.name = "rails-threaded-proxy"
  gem.homepage = "http://github.com/mnutt/rails-threaded-proxy"
  gem.license = "MIT"
  gem.summary = %Q{Threaded reverse proxy for Ruby on Rails}
  gem.description = %Q{Threaded reverse proxy for Ruby on Rails}
  gem.email = "michael@nuttnet.net"
  gem.authors = ["Michael Nutt"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new
