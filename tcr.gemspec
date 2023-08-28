# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tcr/version'

Gem::Specification.new do |gem|
  gem.name          = "tcr"
  gem.version       = TCR::VERSION
  gem.authors       = ["Rob Forman"]
  gem.email         = ["rob@robforman.com"]
  gem.description   = %q{TCR is a lightweight VCR for TCP sockets.}
  gem.summary       = %q{TCR is a lightweight VCR for TCP sockets.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
