class AssignResetEmployeeBalance
  def initialize(employee, time_off_category_id, new_contract_end, old_contract_end = nil)
    @employee = employee
    @time_off_category = employee.account.time_off_categories.find(time_off_category_id)
    @new_contract_end = new_contract_end + 1.day
    @old_contract_end = find_contract_end(old_contract_end)
  end

  def call
    create_reset_employee_balance
    update_balances_valid_after_contract_end
    update_previous_balances_validity_dates
    update_balances
  end

  private

  def create_reset_employee_balance
    @reset_employee_balance =
      CreateEmployeeBalance.new(
        @time_off_category.id,
        @employee.id,
        @employee.account.id,
        balance_type: "reset",
        effective_at: @new_contract_end + Employee::Balance::RESET_OFFSET,
        skip_update: true
      ).call.first
  end

  def update_balances_valid_after_contract_end
    balances_valid_after_contract_end =
      @employee
      .employee_balances
      .in_category(@time_off_category.id)
      .where(
        "effective_at <= ? AND validity_date > ?", @new_contract_end, @new_contract_end
      ).order(:effective_at)
    balances_valid_after_contract_end.map do |balance|
      UpdateEmployeeBalance.new(balance, validity_date: @reset_employee_balance.effective_at).call
    end
  end

  def update_previous_balances_validity_dates
    return unless moved_to_future?
    old_contract_end_balances.map do |balance|
      validity_date =
        RelatedPolicyPeriod
        .new(balance.employee_time_off_policy)
        .validity_date_for_balance_at(balance.effective_at, balance.balance_type)
      UpdateEmployeeBalance.new(balance, validity_date: validity_date).call
    end
  end

  def find_contract_end(old_contract_end)
    return unless old_contract_end.present?
    old_contract_end.beginning_of_day + Employee::Balance::RESET_OFFSET
  end

  def update_balances
    balance =
      if moved_to_future? && @old_contract_end_balances.present?
        @old_contract_end_balances.first
      else
        time_off_balance ? time_off_balance : @reset_employee_balance
      end

    PrepareEmployeeBalancesToUpdate.new(balance, update_all: true).call
    ActiveRecord::Base.after_transaction do
      UpdateBalanceJob.perform_later(balance.id, update_all: true)
    end
  end

  def old_contract_end_balances
    @old_contract_end_balances ||=
      @employee.employee_balances.where(
        validity_date: @old_contract_end, time_off_category: @time_off_category
      ).order(:effective_at)
  end

  def moved_to_future?
    @old_contract_end.present? && @new_contract_end > @old_contract_end
  end

  def time_off_balance
    @employee
      .employee_balances
      .in_category(@time_off_category.id)
      .where(balance_type: "time_off", effective_at: @new_contract_end.beginning_of_day)
      .first
  end
end
