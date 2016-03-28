class RemoveHolidaysModel < ActiveRecord::Migration
  def change
    def up
      drop_table :holidays
    end

    def down
      create_table :holidays, id: :uuid do |t|
        t.string :name, null: false
        t.date :date, null: false
        t.timestamps null: false
        t.uuid :holiday_policy_id, null: false
      end
      add_foreign_key :holidays, :holiday_policies, column: :holiday_policy_id, on_delete: :cascade
      add_index :holidays, :holiday_policy_id
    end
  end
end
