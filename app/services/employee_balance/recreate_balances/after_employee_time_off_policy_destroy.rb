module RecreateBalances
  class AfterEmployeeTimeOffPolicyDestroy
    attr_reader :recreate_balances_helper, :remove_balances_service

    def initialize(destroyed_effective_at:, time_off_category_id:, employee_id:)
      @recreate_balances_helper = RecreateBalancesHelper.new(
        destroyed_effective_at: destroyed_effective_at,
        time_off_category_id: time_off_category_id,
        employee_id: employee_id
      )
      @remove_balances_service = RemoveBalances.new(
        recreate_balances_helper.time_off_category,
        recreate_balances_helper.employee,
        recreate_balances_helper.starting_date,
        recreate_balances_helper.ending_date,
        destroyed_effective_at
      )
    end

    def call
      remove_balances_service.call
      recreate_balances_helper.remove_balance_at_old_effective_at!
      return unless recreate_balances_helper.etops_in_category.exists?
      recreate_balances_helper.recreate_and_recalculate_balances!
    end
  end
end
