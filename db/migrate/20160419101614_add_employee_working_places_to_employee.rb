class AddEmployeeWorkingPlacesToEmployee < ActiveRecord::Migration
  class Employee < ActiveRecord::Base
    has_many :employee_working_places
    has_many :events, class_name: 'Employee::Event'
  end

  class EmployeeWorkingPlace < ActiveRecord::Base
    belongs_to :employee
  end

  def change
    Employee.all.includes(:events).each do |employee|
      hired_date = employee.events.where(event_type: "hired").first.effective_at
      employee.employee_working_places.create(working_place_id: employee.working_place_id, effective_at: hired_date)
    end
  end
end
