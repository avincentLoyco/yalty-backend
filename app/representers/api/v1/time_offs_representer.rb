module Api::V1
  class TimeOffsRepresenter < BaseRepresenter
    def complete
      {
        start_time: resource.start_time,
        end_time: resource.end_time
      }
        .merge(basic)
        .merge(relationships)
    end

    def relationships
      {
        employee: employee_json,
        time_off_category: time_off_category_json,
        employee_balance: employee_balance_json
      }
    end

    def employee_balance_json
      EmployeeBalanceRepresenter.new(resource.employee_balance).with_status
    end

    def employee_json
      EmployeeRepresenter.new(resource.employee).basic
    end

    def time_off_category_json
      TimeOffCategoryRepresenter.new(resource.time_off_category).basic
    end
  end
end
