class MigrateTimeOffBalances < ActiveRecord::Migration
  def change
    Rake::Task['update_and_create_missing_balances:update_and_create'].invoke
  end
end
