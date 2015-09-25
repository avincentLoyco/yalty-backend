class CreateEmployeeAttributesView < ActiveRecord::Migration
  def change
    create_view :employee_attributes
  end
end
