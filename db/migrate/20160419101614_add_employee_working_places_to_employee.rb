class AddEmployeeWorkingPlacesToEmployee < ActiveRecord::Migration
  class Employee < ActiveRecord::Base
    has_many :employee_working_places
  end

  class EmployeeWorkingPlace < ActiveRecord::Base
    belongs_to :employee
  end

  def change
    Employee.all.each do |employee|
      employee.employee_working_places.create(working_place_id: employee.working_place_id, effective_at: employee.created_at)
    end
  end
end
