class RemoveNullConstraintsInTimeOffPolicies < ActiveRecord::Migration
  def change
    change_column_null :time_off_policies, :start_day, true
    change_column_null :time_off_policies, :start_month, true
    change_column_null :time_off_policies, :policy_type, true
  end
end
