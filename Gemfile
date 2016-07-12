source 'https://rubygems.org'

ruby '2.2.2'

gem 'rails',              '4.2.5.1'
gem 'pg',                 '~> 0.18.4'
gem 'bcrypt',             '~> 3.1.10'
gem 'rack-cors',          '~> 0.4.0', require: 'rack/cors'
gem 'doorkeeper',         '~> 3.1.0'
gem 'virtus',             '~> 1.0.5'
gem 'request_store',      '~> 1.3.0'
gem 'scenic',             '~> 1.1.0'
gem 'countries',          '~> 1.2.5'
gem 'holidays',           '~> 4.0'
gem 'gate',               '~> 0.4.1'
gem 'newrelic_rpm',       '~> 3.14.2'
gem 'resque',             '~> 1.25.2'
gem 'resque-web',         '~> 0.0.7', require: 'resque_web'
gem 'tod',                '~> 2.0.2'
gem 'cancancan',          '~> 1.13.1'
gem 'intercom',           '~> 3.3.0'
gem 'resque-scheduler',   '~> 4.0.0'
gem 'active_scheduler',   '~> 0.0.3'

# Production environment dependencies
group :production, :staging, :review do
  gem 'puma',             '~> 2.16.0'
  gem 'rails_12factor',   '~> 0.0.3'
  gem 'therubyracer',     '~> 0.12.2'
end

# Development environment dependencies (also needed by test environement)
group :development, :test do
  gem 'yard', '~> 0.8.7'
  gem 'factory_girl_rails'
  gem 'faker'
  gem 'dotenv-rails'
  gem 'codeclimate-test-reporter', require: false
  gem 'mutant-rspec'

  # improve test speed
  gem 'parallel_tests'

  # debug
  gem 'pry-rails'
  gem 'pry-byebug'
  gem 'byebug'

  # spring
  gem 'spring'
  gem 'spring-commands-rspec'
end

group :test do
  gem 'timecop'
  gem 'rspec-rails', '3.4.0'
  gem 'shoulda-matchers'
  gem 'airborne'
  gem 'temping'
  gem 'guard-rspec'
  gem 'database_cleaner'
  gem 'fantaskspec'
  gem 'fakeredis', '~> 0.5.0'
  gem 'resque_spec', '~> 0.17.0'
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
