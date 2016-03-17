web: bundle exec puma -C config/puma.rb
worker: QUEUE=update_balance,policies_and_balances,mailers,default bundle exec rake environment resque:work
scheduler: bundle exec rake environment resque:scheduler
