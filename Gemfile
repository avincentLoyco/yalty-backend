source "https://rubygems.org"

ruby "2.4.1"

gem "aasm",                 "~> 4.12"
gem "ar_after_transaction", "~> 0.4.1"
gem "attr_extras",          "~> 5.2.0"
gem "bcrypt",               "~> 3.1.10"
gem "cancancan",            "~> 1.13.1"
gem "countries",            "~> 1.2.5"
gem "doorkeeper",           "~> 4.2.6"
gem "dry-validation",       "~> 0.10.5"
gem "geokit",               "~> 1.10.0"
gem "holidays",             "~> 4.0"
gem "intercom",             "~> 3.5.23"
gem "net-sftp",             "~> 2.1.2"
gem "newrelic_rpm",         "~> 3.18.1"
gem "paperclip",            "~> 5.2.0"
gem "pg",                   "~> 0.19.0"
gem "prawn",                "~> 2.2.2"
gem "prawn-table",          "~> 0.2.2"
gem "rack-cors",            "~> 0.4.0", require: "rack/cors"
gem "rails",                "4.2.8"
gem "request_store",        "~> 1.3.0"
gem "scenic",               "~> 1.1.0"
gem "stripe",               "~> 2.0.0"
gem "timezone",             "~> 1.2.3"
gem "tod",                  "~> 2.0.2"
gem "virtus",               "~> 1.0.5"
gem "with_advisory_lock",   "~> 3.2.0"

# background jobs
gem "sidekiq",              "~> 4.2.3"
gem "sidekiq-limit_fetch",  "~> 3.4.0"
gem "sidekiq-scheduler",    "~> 2.0.19"
gem "sidekiq-unique-jobs",  "~> 5.0.4"

# Production environment dependencies
group :production, :staging, :review do
  gem "puma",             "~> 3.8.2"
  gem "rails_12factor",   "~> 0.0.3"
  gem "therubyracer",     "~> 0.12.3"
end

# Development environment dependencies (also needed by test environement)
group :development, :test do
  gem "codeclimate-test-reporter", require: false
  gem "dotenv-rails"
  gem "factory_girl_rails"
  gem "faker"
  gem "json-schema", "~> 2.8.0"
  gem "mutant-rspec"
  gem "simplecov"

  # improve test speed
  gem "parallel_tests"

  # debug
  gem "byebug"
  gem "pry-byebug"
  gem "pry-inline"
  gem "pry-rails"

  # spring
  gem "spring"
  gem "spring-commands-rspec"

  # deploy
  gem "capistrano"
  gem "capistrano-docker-copy", git: "https://github.com/yalty/capistrano-docker-copy.git"
end

group :test do
  gem "airborne"
  gem "database_cleaner"
  gem "db-query-matchers"
  gem "fakeredis", "~> 0.5.0"
  gem "fantaskspec"
  gem "guard-rspec"
  gem "rspec-instafail", require: false
  gem "rspec-rails", "3.4.0"
  gem "shoulda-matchers"
  gem "temping"
  gem "test-prof"
end

# Development environment dependencies (only)
group :development do
  gem "better_errors"
  gem "binding_of_caller"
  gem "letter_opener", "~> 1.4.1"
  gem "meta_request"
  gem "rubocop", "~> 0.52.1"
  gem "rubocop-rspec", "~> 1.22.1"
  gem "web-console", "~> 2.0"
end
