class AddActiveAttributeToTimeOffPolicy < ActiveRecord::Migration
  def change
    add_column :time_off_policies, :active, :bool, null: false, default: true
  end
end
