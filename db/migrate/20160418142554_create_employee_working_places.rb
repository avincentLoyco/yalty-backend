class CreateEmployeeWorkingPlaces < ActiveRecord::Migration
  def change
    create_table :employee_working_places, id: :uuid do |t|
      t.uuid :employee_id,      null: false
      t.uuid :working_place_id, null: false
      t.datetime :effective_at, null: false

    end
    add_foreign_key :employee_working_places,
                    :employees,
                    on_delete: :cascade,
                    column: :employee_id
    add_foreign_key :employee_working_places,
                    :working_places,
                    on_delete: :cascade,
                    column: :working_place_id

    add_index :employee_working_places,
      [:working_place_id, :employee_id, :effective_at],
      unique: true,
      name: "index_employee_id_working_place_id"
  end
end
