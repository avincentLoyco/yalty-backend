require 'resque/server'
require 'resque/scheduler/server'
require 'active_scheduler'

Resque.redis = 'localhost:6379'
yml_schedule    = YAML.load_file("#{Rails.root}/config/resque_scheduler.yml") || {}
wrapped_schedule = ActiveScheduler::ResqueWrapper.wrap yml_schedule
Resque.schedule  = wrapped_schedule
