source 'https://rubygems.org'

ruby '2.2.2'

gem 'rails', '4.2.1'
gem 'pg'
gem 'bcrypt'

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
  gem 'guard-rspec'

  # debug
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
