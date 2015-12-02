class UpdateEmployeeAttributesToVersion3 < ActiveRecord::Migration
  def change
    update_view :employee_attributes, version: 3, revert_to_version: 2
  end
end
