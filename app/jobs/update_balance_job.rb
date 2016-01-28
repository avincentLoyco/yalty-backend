class UpdateBalanceJob < ActiveJob::Base
  attr_reader :employee_balance, :options

  @queue = :balance

  def perform(balance_id, options = {})
    @options = options
    @employee_balance = Employee::Balance.find(balance_id)

    ActiveRecord::Base.transaction do
      options.has_key?(:effective_at) ? find_previous_and_update : update_balances
      update_time_off_status
    end
  end

  def find_previous_and_update
    previous_ids = employee_balance.later_balances_ids

    update_balances(previous_ids)
  end

  def update_balances(previous_ids = nil)
    UpdateEmployeeBalance.new(employee_balance, options).call
    employee_balances = find_balances_by_ids(previous_ids)

    employee_balances.each do |balance|
      UpdateEmployeeBalance.new(balance).call
    end
  end

  def find_balances_by_ids(previous_ids)
    current_ids = employee_balance.later_balances_ids
    ids = previous_ids ? (previous_ids + current_ids).uniq : current_ids

    Employee::Balance.where(id: ids).order(effective_at: :asc)
  end

  def update_time_off_status
    return unless employee_balance.time_off_id.present?
    TimeOff.find(employee_balance.time_off_id).update!(beeing_processed: false)
  end
end
