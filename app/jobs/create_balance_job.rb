class CreateBalanceJob < ActiveJob::Base
  @queue = :balance

  def perform(category_id, employee_id, account_id, amount, time_off_id = nil)
    CreateEmployeeBalance.new(category_id, employee_id, account_id, amount, time_off_id).call
  end
end
