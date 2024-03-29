class MigrateExistingPresencePolicies < ActiveRecord::Migration

  class WorkingPlace < ActiveRecord::Base
    belongs_to :presence_policy
    has_many :employee_working_places
  end

  class EmployeeWorkingPlaces < ActiveRecord::Base
    belongs_to :employee
    belongs_to :working_place
  end

  class EmployeePresencePolicy < ActiveRecord::Base
    belongs_to :employee
    belongs_to :presence_policy
  end

  class Employee < ActiveRecord::Base
    has_many :events, class_name: 'Employee::Event'
    belongs_to :presence_policy
  end


  def change
    Employee.all.each do |employee|
      next unless employee.presence_policy_id
      hired_date = employee.events.where(event_type: "hired").first.effective_at.to_date
      EmployeePresencePolicy.create(
        employee_id: employee.id,
        presence_policy_id: employee.presence_policy_id,
        effective_at: hired_date,
        order_of_start_day: hired_date.wday.to_s.sub('0', '7').to_i
      )
    end

    EmployeeWorkingPlaces.all.each do |employee_working_place|
      next unless employee_working_place.working_place.presence_policy_id
      hired_date =
        employee_working_place.employee.events.where(event_type: "hired").first.effective_at.to_date
      EmployeePresencePolicy.create(
        employee_id: employee_working_place.employee_id,
        presence_policy_id: employee_working_place.working_place.presence_policy_id,
        effective_at: hired_date,
        order_of_start_day: hired_date.wday.to_s.sub('0', '7').to_i
      )
    end
  end
end
