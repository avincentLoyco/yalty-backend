source 'https://rubygems.org'

ruby '2.2.2'

gem 'rails',              '4.2.3'
gem 'pg',                 '~> 0.18.1'
gem 'bcrypt', '~> 3.1.10'
gem 'rack-cors', require: 'rack/cors'
gem 'jsonapi-resources',  '~> 0.5.9'
gem 'doorkeeper',         '~> 2.2.1'
gem 'virtus',             '~> 1.0.5'
gem 'request_store',      '~> 1.2.0'
gem 'scenic',             '~> 0.3.0'
gem 'countries',          '~> 1.1.0'
gem 'holidays',           '~> 2.2.0'


# Production environment dependencies
group :production, :staging do
  gem 'rails_12factor'
  gem 'puma'
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
end
