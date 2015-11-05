class AddPresencePolicyAssosiationToWorkingPlace < ActiveRecord::Migration
  def up
    add_column :working_places, :presence_policy_id, :uuid, index: true, foreign_key: { on_delete: :cascade }
  end

  def down
    remove_column :working_places, :presence_policy_id
  end
end
