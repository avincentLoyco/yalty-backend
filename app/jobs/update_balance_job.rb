class UpdateBalanceJob < ActiveJob::Base
  @queue = :balance

  def perform(employee_balances_ids, amount = nil, time_off_id = nil)
    employee_balances = Employee::Balance.where(id: employee_balances_ids).order(created_at: :asc)
    ActiveRecord::Base.transaction do
      update_employee_balances(employee_balances, amount)
      update_time_off_status(time_off_id) unless time_off_id.blank?
    end
  end

  def update_employee_balances(employee_balances, amount)
    employee_balances.each_with_index do |employee_balance, index|
      if index == 0 && amount.present?
        UpdateEmployeeBalance.new(employee_balance, amount).call
      else
        UpdateEmployeeBalance.new(employee_balance).call
      end
    end
  end

  def update_time_off_status(time_off_id)
    TimeOff.find(time_off_id).update!(beeing_processed: false)
  end
end
