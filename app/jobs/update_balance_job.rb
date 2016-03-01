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
    employee_balances = find_balances_by_ids
    UpdateEmployeeBalance.new(employee_balance, options).call

    employee_balances.each do |balance|
      UpdateEmployeeBalance.new(balance).call
    end
  end

  def find_balances_by_ids
    Employee::Balance.where(id: balances_to_update).order(effective_at: :asc)
  end

  def update_time_off_status
    return unless employee_balance.time_off_id.present?
    TimeOff.find(employee_balance.time_off_id).update!(beeing_processed: false)
  end

  def balances_to_update
    return employee_balance.all_later_ids(earlier_date) if options[:effective_at]
    employee_balance.later_balances_ids(current_or_new_amount)
  end

  def earlier_date
    options[:effective_at] < employee_balance.effective_at ?
      options[:effective_at] : employee_balance.effective_at
  end

  def current_or_new_amount
    options[:amount] || employee_balance.amount
  end
end
