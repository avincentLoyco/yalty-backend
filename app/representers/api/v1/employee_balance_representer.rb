module Api::V1
  class EmployeeBalanceRepresenter < BaseRepresenter
    def complete
      {
        amount: resource.amount,
        balance: resource.balance,
        effective_at: resource.effective_at,
        being_processed: resource.being_processed,
        validity_date: resource.validity_date,
        policy_credit_addition: resource.policy_credit_addition
      }
        .merge(basic)
        .merge(relationship)
    end

    def with_status
      {
        amount: resource.amount,
        balance: resource.balance,
        effective_at: resource.effective_at,
        being_processed: resource.being_processed
      }
        .merge(basic)
    end

    def relationship
      {
        employee: employee_json,
        time_off_category: time_off_category_json,
        time_off_policy: time_off_policy_json,
        time_off: time_off_json
      }
    end

    def balances_sum
      return [] if resource.blank?
      resource.first.employee.unique_balances_categories.map do |category|
        EmployeeBalanceRepresenter.new(
          resource.first.employee.last_balance_in_category(category.id)
        ).complete.merge(time_off_category: time_off_category_json(category))
      end
    end

    private

    def time_off_json
      return nil unless resource.time_off.present?
      TimeOffsRepresenter.new(resource.time_off).basic
    end

    def employee_json
      EmployeeRepresenter.new(resource.employee).basic
    end

    def time_off_category_json(category = resource.time_off_category)
      TimeOffCategoryRepresenter.new(category).basic
    end

    def time_off_policy_json
      TimeOffPolicyRepresenter.new(resource.time_off_policy).basic
    end
  end
end
