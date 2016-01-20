class CreateWorkingPlaceTimeOffPolicy < ActiveRecord::Migration
  def change
    create_table :working_place_time_off_policies, id: :uuid do |t|
      t.uuid :working_place_id, null: false
      t.uuid :time_off_policy_id, null: false
    end
    add_foreign_key :working_place_time_off_policies,
                    :working_places,
                    on_delete: :cascade,
                    column: :working_place_id
    add_foreign_key :working_place_time_off_policies,
                    :time_off_policies,
                    on_delete: :cascade,
                    column: :time_off_policy_id
    add_index :working_place_time_off_policies, :working_place_id
    add_index :working_place_time_off_policies, :time_off_policy_id
  end
end
