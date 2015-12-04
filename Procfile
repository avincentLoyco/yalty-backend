web: bundle exec puma -C config/puma.rb
worker: QUEUE=default bundle exec rake environment resque:work
