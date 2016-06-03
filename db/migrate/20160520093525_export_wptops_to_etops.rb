class ExportWptopsToEtops < ActiveRecord::Migration
  class Employee < ActiveRecord::Base
    has_many :employee_time_off_policies
    has_many :employee_working_places
    has_many :events, class_name: 'Employee::Event'
  end

  class WorkingPlace < ActiveRecord::Base
    has_many :working_place_time_off_policies
    has_many :employee_working_places
    has_many :employees, through: :employee_working_places
  end

  class EmployeeWorkingPlaces < ActiveRecord::Base
    belongs_to :employee
    belongs_to :working_place
  end

  class EmployeeTimeOffPolicy < ActiveRecord::Base
    belongs_to :time_off_policy
    belongs_to :employee
  end

  class WorkingPlaceTimeOffPolicy < ActiveRecord::Base
    belongs_to :time_off_policy
    belongs_to :working_place
  end

  def change
    EmployeeTimeOffPolicy.all.each do |etop|
      hire_date =
        etop.employee.events.where(event_type: "hired").first.effective_at.to_date
      etop.update_attribute(:effective_at, hire_date)
    end
    WorkingPlaceTimeOffPolicy.all.each do |wptop|
      wptop.working_place.employees.each do |employee|
        hire_date = employee.events.where(event_type: "hired").first.effective_at.to_date
        EmployeeTimeOffPolicy.create(
          employee: employee,
          time_off_policy_id: wptop.time_off_policy_id,
          effective_at: hire_date
        )
      end
    end
  end
end
