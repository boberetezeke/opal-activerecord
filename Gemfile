source 'https://rubygems.org'

gemspec

gem 'opal',       github: 'opal/opal'
# gem 'opal', path: '../opal'
gem 'opal-rspec', '~> 0.4.0.beta4'

gem 'rspec' # for testing in MRI

group :test do
  # for testing compatibility with non-opal activerecord
  gem 'activerecord'
  gem 'sqlite3'
end
