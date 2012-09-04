# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jsonrpc/version'

Gem::Specification.new do |gem|
  gem.name          = "jsonrpc-client"
  gem.version       = JSONRPC::VERSION
  gem.authors       = ["Pavel Forkert"]
  gem.email         = ["fxposter@gmail.com"]
  gem.description   = %q{Simple JSON-RPC 2.0 client implementation}
  gem.summary       = %q{JSON-RPC 2.0 client}
  gem.homepage      = "https://github.com/fxposter/jsonrpc-client"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'faraday'
  gem.add_dependency 'multi_json', '>= 1.1.0'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'rake'
end
