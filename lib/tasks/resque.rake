require 'resque/tasks'
require 'resque/scheduler/tasks'

task "resque:setup" => :environment do
  Resque.before_fork = Proc.new do |job|
    ActiveRecord::Base.connection.disconnect!
  end
  Resque.after_fork = Proc.new do |job|
    ActiveRecord::Base.establish_connection
  end
end
