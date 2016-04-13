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
    employee_balances = Employee::Balance.where(id: balances_to_update).order(effective_at: :asc)
    UpdateEmployeeBalance.new(employee_balance, options).call

    employee_balances.each do |balance|
      UpdateEmployeeBalance.new(balance).call
    end
  end

  def update_time_off_status
    return unless employee_balance.time_off_id.present?
    TimeOff.find(employee_balance.time_off_id).update!(being_processed: false)
  end
end
