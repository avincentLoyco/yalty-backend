class AddActiveAttributeToTimeOffPolicy < ActiveRecord::Migration
  def change
    add_column :time_off_policies, :active, :bool
    change_column_null :time_off_policies, :active, false, true
    change_column_default :time_off_policies, :active, true
  end
end
