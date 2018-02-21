namespace :db do
  desc "Test if some migrations pending"
  task pending: [:environment] do
    ActiveRecord::Migration.check_pending!
  end
end
