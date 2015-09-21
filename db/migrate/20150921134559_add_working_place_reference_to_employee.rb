class AddWorkingPlaceReferenceToEmployee < ActiveRecord::Migration
  def up
    add_reference :employees, :working_place, index: true, foreign_key: { on_delete: :cascade }
  end

  def down
    remove_reference :employees, :working_place
  end
end
