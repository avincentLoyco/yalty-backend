require 'employee_category_policy_finder'

class AddPolicyAdditionsJob < ActiveJob::Base
  queue_as :policies_and_balances

  def perform
    finder = EmployeeCategoryPolicyFinder.new(Time.zone.today)
    mixed_table_data =
      finder.data_from_employees_with_employee_policy_for_day_and_month
    mixed_table_data.each do |hash|
      hash['policy_type'] == 'counter' ? manage_counter(hash) : manage_balancer(hash)
    end
  end

  private

  def manage_counter(attributes_hash)
    options = { policy_credit_addition: true }
    CreateEmployeeBalance.new(
      attributes_hash['time_off_category_id'],
      attributes_hash['employee_id'],
      attributes_hash['account_id'],
      nil,
      options
    ).call
  end

  def manage_balancer(attributes_hash)
    options = options_for_balancer(attributes_hash)
    CreateEmployeeBalance.new(
      attributes_hash['time_off_category_id'],
      attributes_hash['employee_id'],
      attributes_hash['account_id'],
      attributes_hash['amount'],
      options
    ).call
  end

  def options_for_balancer(attributes_hash)
    {
      policy_credit_addition: true,
      validity_date: policy_end_date(
        attributes_hash['end_day'],
        attributes_hash['end_month'],
        attributes_hash['years_to_effect'],
        attributes_hash['years_passed)']
      )
    }
  end

  def policy_end_date(end_day, end_month, years_to_effect, years_passed)
    return nil if end_day.blank? && end_month.blank?
    add_years = years_to_effect > 1 ? years_to_effect : 1
    Date.new(Time.zone.today.year - years_passed + add_years, end_month, end_day)
  end
end
