class AddDefaultFullTimePresencePolicyFlag < ActiveRecord::Migration
  def change
    add_column :presence_policies, :default_full_time, :bool, null: false, default: false
  end
end
