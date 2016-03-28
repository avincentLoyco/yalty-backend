class AllowAmountNullForCounter < ActiveRecord::Migration
  def change
    change_column_null :time_off_policies, :amount, true
    change_column_default :time_off_policies, :amount, nil
  end
end
