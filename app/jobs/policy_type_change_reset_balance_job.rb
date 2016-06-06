require 'employee_category_policy_finder'

class PolicyTypeChangeResetBalanceJob < ActiveJob::Base
  queue_as :policies_and_balances
  # TO DO
  def perform
    today = Time.zone.today
    finder = EmployeeCategoryPolicyFinder.new
    mixed_table_data =
      finder.data_from_employees_with_employee_policy_for_effective_date_at(today.to_s)
    mixed_table_data.each do |hash|
      create_reset_balance(hash)
    end
  end

  private

  def create_reset_balance(attributes_hash)
    options = { reset_balance: true }
    CreateEmployeeBalance.new(
      attributes_hash['time_off_category_id'],
      attributes_hash['employee_id'],
      attributes_hash['account_id'],
      0,
      options
    ).call
  end
end
