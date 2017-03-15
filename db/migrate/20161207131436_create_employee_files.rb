class CreateEmployeeFiles < ActiveRecord::Migration
  def change
    create_table :employee_files, id: :uuid do |t|
      t.timestamps
    end
    add_attachment :employee_files, :file
  end
end
