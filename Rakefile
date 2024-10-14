# frozen_string_literal: true

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  warn e.message
  warn 'Run `bundle install` to install missing gems'
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://guides.rubygems.org/specification-reference/ for more options
  gem.name = 'rails-threaded-proxy'
  gem.homepage = 'http://github.com/mnutt/rails-threaded-proxy'
  gem.license = 'MIT'
  gem.summary = %(Threaded reverse proxy for Ruby on Rails)
  gem.description = %(Threaded reverse proxy for Ruby on Rails)
  gem.email = 'michael@nuttnet.net'
  gem.authors = ['Michael Nutt']
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new
