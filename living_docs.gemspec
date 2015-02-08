# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
name = "living_docs"

require "#{name}/version"

Gem::Specification.new name, LivingDocs::VERSION do |s|
  s.summary = "A C documentation tool which compiles example code from comments"
  s.authors = ["Aiden Nibali"]
  s.email = "aiden@nibali.org"
  s.homepage = "https://github.com/anibali/#{name}"
  s.files = `git ls-files lib/ bin/ res/`.split("\n")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'ffi-clang'
  s.add_runtime_dependency 'redcarpet'
  s.add_runtime_dependency 'pygments.rb'
  s.add_runtime_dependency 'haml'
  s.add_runtime_dependency 'erubis'
end
