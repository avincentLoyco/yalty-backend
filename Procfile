web: bundle exec puma -C config/puma.rb
worker: QUEUE=mailers,default bundle exec rake environment resque:work
