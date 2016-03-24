class CreateEmployeeBalancesForTimeOffs < ActiveRecord::Migration
  def change
    Rake::Task[:create_balances_for_time_offs].invoke
  end
end
