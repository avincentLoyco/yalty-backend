class CreateEmployeeEvents < ActiveRecord::Migration
  def change
    create_table :employee_events do |t|
      t.references :employee, index: true, foreign_key: { on_delete: :cascade }
      t.datetime :effective_at
      t.text :comment

      t.timestamps null: false
    end

    add_reference :employee_attribute_versions, :employee_event, foreign_key: true, index: true
  end
end
