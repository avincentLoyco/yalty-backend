class UpdateEmployeeAttributesToVersion4 < ActiveRecord::Migration
  def change
    update_view :employee_attributes, version: 4, revert_to_version: 3
  end
end
