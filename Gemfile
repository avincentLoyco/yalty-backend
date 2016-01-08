source 'https://rubygems.org'

ruby '2.2.2'

gem 'rails',              '4.2.3'
gem 'pg',                 '~> 0.18.1'
gem 'bcrypt',             '~> 3.1.10'
gem 'rack-cors',          '~> 0.4.0',   require: 'rack/cors'
gem 'doorkeeper',         '~> 2.2.1'
gem 'virtus',             '~> 1.0.5'
gem 'request_store',      '~> 1.2.0'
gem 'scenic',             '~> 0.3.0'
gem 'countries',          '~> 1.1.0'
gem 'holidays',           '~> 2.2.0'
gem 'gate',               '~> 0.4.1'
gem 'newrelic_rpm',       '~> 3.14.0'
gem 'resque',             '~> 1.25.2'
gem 'resque-web',         '~> 0.0.7',   require: 'resque_web'

# Production environment dependencies
group :production, :staging, :review do
  gem 'puma',             '~> 2.13.4'
  gem 'rails_12factor',   '~> 0.0.3'
  gem 'therubyracer',     '~> 0.12.2'
  gem 'intercom',         '~> 3.3.0'
end

# Development environment dependencies (also needed by test environement)
group :development, :test do
  gem 'dotenv-rails'
  gem 'codeclimate-test-reporter', require: false

  # tests
  gem 'rspec-rails'
  gem 'shoulda-matchers', require: false
  gem 'factory_girl_rails'
  gem 'airborne'
  gem 'faker'
  gem 'temping'
  gem 'guard-rspec'
  gem 'database_cleaner'
  gem 'fantaskspec'
  gem 'resque_spec', '~> 0.17.0'

  # debug
  gem 'pry-rails'
  gem 'pry-byebug'
  gem 'byebug'

  # spring
  gem 'spring'
  gem 'spring-commands-rspec'
end

# Development environment dependencies (only)
group :development do
  gem 'meta_request'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'web-console', '~> 2.0'
  gem 'apiaryio'
  gem 'letter_opener', '~> 1.4.1'
end
