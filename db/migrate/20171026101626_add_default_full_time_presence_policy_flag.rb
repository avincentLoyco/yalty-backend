class AddDefaultFullTimePresencePolicyFlag < ActiveRecord::Migration
  def change
    add_column :presence_policies, :default_full_time, :bool, null: false
    change_column_default(:presence_policies, :default_full_time, false)
  end
end
