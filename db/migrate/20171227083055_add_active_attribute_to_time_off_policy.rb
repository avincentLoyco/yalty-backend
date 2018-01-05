class AddActiveAttributeToTimeOffPolicy < ActiveRecord::Migration
  def change
    add_column :time_off_policies, :active, :bool, null: false
    change_column_default(:time_off_policies, :active, true)
  end
end
