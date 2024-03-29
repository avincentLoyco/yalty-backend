module Api::V1
  class TimeOffPolicyRepresenter < BaseRepresenter
    def complete
      {
        name: resource.name,
        start_day: resource.start_day,
        end_day: resource.end_day,
        start_month: resource.start_month,
        end_month: resource.end_month,
        amount: resource.amount,
        policy_type: resource.policy_type,
        years_to_effect: resource.years_to_effect,
        active: resource.active,
        deletable: assigned_employees_json.empty?,
      }
        .merge(basic)
        .merge(time_off_category: time_off_category_json)
    end

    def with_relationships
      complete.merge(assigned_employees: assigned_employees_json)
    end

    def time_off_category_json
      TimeOffCategoryRepresenter.new(resource.time_off_category).basic
    end

    def assigned_employees_json
      related_resources(EmployeeTimeOffPolicy, resource.id).map do |employee_time_off_policy|
        EmployeeTimeOffPolicyRepresenter.new(employee_time_off_policy).complete
      end
    end
  end
end
