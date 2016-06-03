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
  end


  def change
    EmployeeWorkingPlaces.all.each do |employee_working_place|
      next unless employee_working_place.working_place.presence_policy_id
      EmployeePresencePolicy.create(
        employee_id: employee_working_place.employee_id,
        presence_policy_id: employee_working_place.working_place.presence_policy_id,
        effective_at: employee_working_place.employee.events.where(event_type: "hired").first.effective_at.to_date
      )
    end
  end
end
