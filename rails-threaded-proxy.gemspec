# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-
# stub: rails-threaded-proxy 0.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "rails-threaded-proxy".freeze
  s.version = "0.3.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Michael Nutt".freeze]
  s.date = "2024-10-14"
  s.description = "Threaded reverse proxy for Ruby on Rails".freeze
  s.email = "michael@nuttnet.net".freeze
  s.executables = ["bundle".freeze, "htmldiff".freeze, "jeweler".freeze, "ldiff".freeze, "nokogiri".freeze, "racc".freeze, "rackup".freeze, "rake".freeze, "rdoc".freeze, "ri".freeze, "rspec".freeze, "rubocop".freeze, "semver".freeze]
  s.extra_rdoc_files = [
    "LICENSE"
  ]
  s.files = [
    ".bundle/config",
    ".rspec",
    ".rubocop.yml",
    ".ruby-version",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE",
    "Rakefile",
    "VERSION",
    "bin/bundle",
    "bin/htmldiff",
    "bin/jeweler",
    "bin/ldiff",
    "bin/nokogiri",
    "bin/racc",
    "bin/rackup",
    "bin/rake",
    "bin/rdoc",
    "bin/ri",
    "bin/rspec",
    "bin/rubocop",
    "bin/semver",
    "lib/rails-threaded-proxy.rb",
    "lib/threaded-proxy.rb",
    "lib/threaded_proxy.rb",
    "lib/threaded_proxy/client.rb",
    "lib/threaded_proxy/controller.rb",
    "lib/threaded_proxy/http.rb",
    "rails-threaded-proxy.gemspec",
    "spec/spec_helper.rb",
    "spec/threaded_proxy/client_spec.rb"
  ]
  s.homepage = "http://github.com/mnutt/rails-threaded-proxy".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.5.16".freeze
  s.summary = "Threaded reverse proxy for Ruby on Rails".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<actionpack>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<addressable>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<bundler>.freeze, ["~> 2.0".freeze])
  s.add_development_dependency(%q<jeweler>.freeze, ["~> 2.3.9".freeze])
  s.add_development_dependency(%q<nokogiri>.freeze, [">= 1.16.7".freeze])
  s.add_development_dependency(%q<rdoc>.freeze, ["~> 6.7.0".freeze])
  s.add_development_dependency(%q<rspec>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rubocop>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<webrick>.freeze, [">= 0".freeze])
end

