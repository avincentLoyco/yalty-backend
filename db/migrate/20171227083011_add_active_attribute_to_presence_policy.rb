class AddActiveAttributeToPresencePolicy < ActiveRecord::Migration
  def change
    add_column :presence_policies, :active, :bool, null: false, default: true
  end
end
