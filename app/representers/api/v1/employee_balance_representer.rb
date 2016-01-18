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
        time_off_category: time_off_category_json,
        time_off_policy: time_off_policy_json
      }
    end

    def balances_sum
      return [] if resource.blank?
      resource.first.employee.unique_balances_categories.map do |category|
        CategoryBalanceRepresenter.new(resource.first.employee, category).basic
      end
    end

    def employee_json
      EmployeeRepresenter.new(resource.employee).basic
    end

    def time_off_category_json
      TimeOffCategoryRepresenter.new(resource.time_off_category).basic
    end

    def time_off_policy_json
      TimeOffPolicyRepresenter.new(resource.time_off_policy).basic
    end
  end
end
