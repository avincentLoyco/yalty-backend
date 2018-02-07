class ChangeDefaultAmountOfTimeOffPolicyToZero < ActiveRecord::Migration
  def change
    change_column_null :time_off_policies, :amount, false
    change_column_default :time_off_policies, :amount, 0
  end
end
