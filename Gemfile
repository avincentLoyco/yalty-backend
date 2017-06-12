source 'https://rubygems.org'

ruby '2.3.3'

gem 'ar_after_transaction', '~> 0.4.1'
gem 'bcrypt',               '~> 3.1.10'
gem 'cancancan',            '~> 1.13.1'
gem 'countries',            '~> 1.2.5'
gem 'doorkeeper',           '~> 4.2.0'
gem 'dry-validation',       '~> 0.9.2'
gem 'geokit',               '~> 1.10.0'
gem 'holidays',             '~> 4.0'
gem 'intercom',             '~> 3.3.0'
gem 'net-sftp',             '~> 2.1.2'
gem 'newrelic_rpm',         '~> 3.14.2'
gem 'paperclip',            '~> 5.0.0'
gem 'pg',                   '~> 0.19.0'
gem 'prawn',                '~> 2.2.2'
gem 'prawn-table',          '~> 0.2.2'
gem 'rack-cors',            '~> 0.4.0', require: 'rack/cors'
gem 'rails',                '4.2.7.1'
gem 'request_store',        '~> 1.3.0'
gem 'scenic',               '~> 1.1.0'
gem 'stripe',               '~> 2.0.0'
gem 'timezone',             '~> 1.2.3'
gem 'tod',                  '~> 2.0.2'
gem 'virtus',               '~> 1.0.5'

# background jobs
gem 'sidekiq',              '~> 4.2.3'
gem 'sidekiq-limit_fetch',  '~> 3.4.0'
gem 'sidekiq-scheduler',    '~> 2.0.19'
gem 'sidekiq-unique-jobs',  '~> 5.0.4'

# Production environment dependencies
group :production, :staging, :review do
  gem 'puma',             '~> 3.6.2'
  gem 'rails_12factor',   '~> 0.0.3'
  gem 'therubyracer',     '~> 0.12.2'
end

# Development environment dependencies (also needed by test environement)
group :development, :test do
  gem 'codeclimate-test-reporter', require: false
  gem 'dotenv-rails'
  gem 'factory_girl_rails'
  gem 'faker'
  gem 'mutant-rspec'
  gem 'simplecov'
  gem 'yard', '~> 0.8.7'

  # improve test speed
  gem 'parallel_tests'

  # debug
  gem 'byebug'
  gem 'pry-byebug'
  gem 'pry-rails'

  # spring
  gem 'spring'
  gem 'spring-commands-rspec'

  # deploy
  gem 'capistrano'
  gem 'capistrano-docker-copy', git: 'https://github.com/yalty/capistrano-docker-copy.git'
end

group :test do
  gem 'airborne'
  gem 'database_cleaner'
  gem 'fakeredis', '~> 0.5.0'
  gem 'fantaskspec'
  gem 'guard-rspec'
  gem 'rspec-rails', '3.4.0'
  gem 'shoulda-matchers'
  gem 'temping'
  gem 'timecop'
end

# Development environment dependencies (only)
group :development do
  gem 'apiaryio'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'letter_opener', '~> 1.4.1'
  gem 'meta_request'
  gem 'web-console', '~> 2.0'
end
