source 'https://rubygems.org'

ruby '2.2.2'

gem 'rails', '4.2.1'
gem 'pg'

# Production environment dependencies
group :production, :staging do
end

# Development environment dependencies (also needed by test environement)
group :development, :test do
  gem 'dotenv-rails'

  # debug
  gem 'byebug'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'web-console', '~> 2.0'

  # spring
  gem 'spring'
end

