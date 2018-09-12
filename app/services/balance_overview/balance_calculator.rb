module BalanceOverview
  class BalanceCalculator
    method_object [:daterange!, :employee!, :category!]

    delegate :employee_balances, to: :employee
    delegate :min, :max, to: :daterange

    def call
      return 0 unless balance_calculatable?
      last_balance.balance + future_timeoff_balances_sum
    end

    private

    def last_balance
      @last_balance ||=
        employee_balances.in_category(category.id).between(min, max).recent.first
    end

    def balance_calculatable?
      last_balance.present? && daterange.present?
    end

    def future_timeoff_balances_sum
      employee_balances
        .in_category(category.id)
        .where(balance_type: "time_off")
        .where(Employee::Balance.arel_table[:effective_at].gt(max))
        .sum(:resource_amount)
    end
  end
end
