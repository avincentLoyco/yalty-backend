module Api::V1
  class WorkingPlaceRepresenter < BaseRepresenter
    def complete
      {
        name: resource.name
      }
        .merge(basic)
        .merge(relationships)
    end

    def relationships
      holiday_policy = HolidayPolicyRepresenter.new(resource.holiday_policy).basic
      employees = resource.employees.map do |employee|
        EmployeeRepresenter.new(employee).basic
      end
      {
        holiday_policy: holiday_policy,
        employees: employees
      }
    end
  end
end
