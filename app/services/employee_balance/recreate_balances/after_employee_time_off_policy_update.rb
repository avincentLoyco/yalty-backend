module RecreateBalances
  class AfterEmployeeTimeOffPolicyUpdate
    attr_reader :recreate_balances_helper, :remove_balances_service

    def initialize(
      new_effective_at:,
      old_effective_at:,
      time_off_category_id:,
      employee_id:,
      manual_amount: 0
    )
      @recreate_balances_helper = RecreateBalancesHelper.new(
        new_effective_at: new_effective_at + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
        old_effective_at: old_effective_at,
        time_off_category_id: time_off_category_id,
        employee_id: employee_id,
        manual_amount: manual_amount
      )
      @remove_balances_service = RemoveBalances.new(
        recreate_balances_helper.time_off_category,
        recreate_balances_helper.employee,
        recreate_balances_helper.starting_date,
        recreate_balances_helper.ending_date,
        old_effective_at
      )
    end

    def call
      remove_balances_service.call
      recreate_balances_helper.remove_balance_at_old_effective_at!
      recreate_balances_helper.recreate_and_recalculate_balances!
    end
  end
end
