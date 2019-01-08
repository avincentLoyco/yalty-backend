class AddArchivedFlagToPresencePolicies < ActiveRecord::Migration
  def change
    add_column :presence_policies, :archived, :boolean
    change_column_default :presence_policies, :archived, false
    execute("UPDATE presence_policies set archived = false")
    change_column_null :presence_policies, :archived, false
  end
end
