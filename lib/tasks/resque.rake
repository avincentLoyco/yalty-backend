require 'resque/tasks'
require 'resque/scheduler/tasks'

task 'resque:setup' => :environment do
  Resque.before_fork = proc do |_job|
    ActiveRecord::Base.connection.disconnect!
  end
  Resque.after_fork = proc do |_job|
    ActiveRecord::Base.establish_connection
  end
end
