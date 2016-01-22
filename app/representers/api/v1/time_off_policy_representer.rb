module Api::V1
  class TimeOffPolicyRepresenter < BaseRepresenter
    def complete
      {
        start_day: resource.start_day,
        end_day: resource.end_day,
        start_month: resource.start_month,
        end_month: resource.end_month,
        amount: resource.amount,
        policy_type: resource.policy_type,
        years_to_effect: resource.years_to_effect,
      }
        .merge(basic)
        .merge(relationships)
    end

    def relationships
      {
        time_off_category: time_off_category_json,
        employees: employees_json,
        working_places: working_places_json,
      }
    end

    def time_off_category_json
      TimeOffCategoryRepresenter.new(resource.time_off_category).basic
    end

    def employees_json
      resource.employees.map do |employee|
        EmployeeRepresenter.new(employee).basic
      end
    end

    def working_places_json
      resource.working_places.map do |working_place|
        WorkingPlaceRepresenter.new(working_place).basic
      end
    end
  end
end
