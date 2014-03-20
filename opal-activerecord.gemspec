# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'opal/activerecord/version'

Gem::Specification.new do |gem|
  gem.name          = 'opal-activerecord'
  gem.version       = Opal::Activerecord::VERSION
  gem.authors       = ['Steve Tuckner']
  gem.email         = ['stevetuckner@stewdle.com']
  gem.summary       = %q{A small port of the glorious ActiveRecord for Opal}
  gem.description   = %q{
                        This implements a subset of the rails/activerecord.
                        It currently handles has_many and belongs_to
                        associations, saving, finding and simple where
                        queries. 
                      }
  gem.licenses      = ['MIT']
  gem.homepage      = 'https://github.com/boberetezeke/opal-activerecord'
  gem.rdoc_options << '--main' << 'README' <<
                      '--line-numbers' <<
                      '--include' << 'opal'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_dependency 'opal', ['>= 0.5.0', '< 1.0.0']
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'opal-rspec'
end
