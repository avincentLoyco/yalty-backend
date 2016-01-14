module Api::V1
  class EmployeeBalanceRepresenter < BaseRepresenter
    def complete
      {
        amount: resource.amount,
        balance: resource.balance
      }
        .merge(basic)
        .merge(relationship)
    end

    def relationship
      {
        employee: employee_json,
        time_off_category: time_off_category_json
      }
    end

    def employee_json
      EmployeeRepresenter.new(resource.employee).basic
    end

    def time_off_category_json
      TimeOffCategoryRepresenter.new(resource.time_off_category).basic
    end
  end
end
