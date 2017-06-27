class UpdateBalanceJob < ActiveJob::Base
  attr_reader :employee_balance, :options

  queue_as :update_balance

  def perform(balance_id, options = {})
    @options = options
    @employee_balance = Employee::Balance.find(balance_id)

    ActiveRecord::Base.transaction do
      update_balances
      update_time_off_status
    end
  end

  private

  def update_balances
    balances_to_update = FindEmployeeBalancesToUpdate.new(@employee_balance, options).call
    options.delete(:update_all)
    employee_balances = Employee::Balance.where(id: balances_to_update).order(effective_at: :asc)
    UpdateEmployeeBalance.new(employee_balance, options).call
    balances_to_update = employee_balances_with_removal(employee_balances)
    balances_to_update.each do |balance|
      removal = balance.balance_credit_removal
      UpdateEmployeeBalance.new(balance).call
      next unless removal.nil? && balance.reload.balance_credit_removal.present?
      index = find_index_for_balance(balances_to_update, balance.balance_credit_removal)
      balances_to_update.to_a.insert(index, balance.reload.balance_credit_removal)
    end
  end

  def find_index_for_balance(balances, removal)
    previous = balances.select { |balance| balance[:effective_at] < removal.effective_at }.last
    previous_index = balances.find_index(previous)
    previous_index ? previous_index + 1 : balances.size + 1
  end

  def update_time_off_status
    return unless employee_balance.time_off_id.present?
    TimeOff.find(employee_balance.time_off_id).update!(being_processed: false)
  end

  def employee_balances_with_removal(employee_balances)
    return employee_balances unless employee_balance.reload.balance_credit_removal
    (employee_balances + [employee_balance.reload.balance_credit_removal])
      .compact.uniq.sort_by { |eb| eb[:effective_at] }
  end
end
