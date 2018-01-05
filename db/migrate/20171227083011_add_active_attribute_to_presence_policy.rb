class AddActiveAttributeToPresencePolicy < ActiveRecord::Migration
  def change
    add_column :presence_policies, :active, :bool, null: false
    change_column_default(:presence_policies, :active, true)
  end
end
