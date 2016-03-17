web: bundle exec puma -C config/puma.rb
worker: QUEUE=mailers,default,update_balance,policies_and_balances bundle exec rake environment resque:work
scheduler: bundle exec rake resque:scheduler
