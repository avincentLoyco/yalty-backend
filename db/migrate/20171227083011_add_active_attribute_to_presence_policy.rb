class AddActiveAttributeToPresencePolicy < ActiveRecord::Migration
  def change
    add_column :presence_policies, :active, :bool
    change_column_null :presence_policies, :active, false, true
    change_column_default :presence_policies, :active, true
  end
end
