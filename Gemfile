source 'https://rubygems.org'

ruby '2.2.2'

gem 'rails', '4.2.3'
gem 'pg'
gem 'bcrypt'
gem 'rack-cors', require: 'rack/cors'
gem 'jsonapi-resources'
gem 'doorkeeper'
gem 'virtus'
gem 'request_store'

# Production environment dependencies
group :production, :staging do
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
