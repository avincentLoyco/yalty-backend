class ManageEmployeeBalanceAdditions
  attr_reader :resource, :employee, :effective_at, :balances, :effective_till

  def initialize(resource)
    @resource = resource
    @employee = resource.employee
    @effective_at = resource.effective_at
    @effective_till = calculate_effective_till
    @balances = []
  end

  def call
    return if RelatedPolicyPeriod.new(resource).first_start_date > effective_till
    ActiveRecord::Base.transaction do
      create_additions_with_removals
      PrepareEmployeeBalancesToUpdate.new(balances.flatten.first).call if balances.flatten.present?
    end
    check_amount_and_update_balances
  end

  private

  def check_amount_and_update_balances
    return unless balances.flatten.present?
    unless balances.flatten.map { |b| [b[:manual_amount], b[:resource_amount]] }.flatten.uniq == [0]
      ActiveRecord::Base.after_transaction do
        UpdateBalanceJob.perform_later(balances.flatten.first)
      end
    end
  end

  def create_additions_with_removals
    etops_between_dates.each do |etop|
      balance_date = RelatedPolicyPeriod.new(etop).first_start_date
      date_to_which_create_balances = etop.effective_till || ending_date

      while balance_date <= date_to_which_create_balances
        if addition_at(balance_date).nil?
          balances << CreateEmployeeBalance.new(*employee_balance_params(etop, balance_date)).call
        end
        if create_before_start_date_balance?(balance_date)
          balances <<
            CreateEmployeeBalance.new(*employee_balance_params(etop, balance_date - 1.day, true)).call
        end
        balance_date += 1.year
      end
    end
  end

  def etops_between_dates
    @etops_between_dates = employee
                           .employee_time_off_policies
                           .where('effective_at BETWEEN ? AND ?', starting_date, ending_date)
  end

  def starting_date
    @starting_date = resource.effective_at
  end

  def ending_date
    @ending_date = future_policy_period_last_date
  end

  def create_before_start_date_balance?(date)
    active_policy_at(date - 1.day).present? &&
      balance_is_not_assignation?(date) &&
      day_before_balance_at(date - 1.day).nil?
  end

  def addition_at(date)
    employee.employee_balances.find_by(
      'effective_at = ?', date + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET)
  end

  def day_before_balance_at(date)
    employee.employee_balances.find_by(
      'effective_at = ?', date + Employee::Balance::DAY_BEFORE_START_DAY_OFFSET)
  end

  def employee_balance_params(etop, date, for_day_before = false)
    [
      etop.time_off_category_id,
      etop.employee_id,
      employee.account_id,
      policy_type_options(etop, date, for_day_before)
    ]
  end

  def policy_type_options(etop, date, for_day_before)
    base_options =
      if for_day_before
        options_for_day_before_start_date(date)
      else
        default_options(etop, date)
      end
    return base_options if etop.time_off_policy.counter?
    base_options.merge(validity_date: validity_date_for_base_options(date, for_day_before))
  end

  def default_options(etop, date)
    {
      skip_update: true,
      policy_credit_addition: true,
      effective_at: date + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
      resource_amount: etop.time_off_policy.amount
    }
  end

  def options_for_day_before_start_date(date)
    {
      skip_update: true,
      policy_credit_addition: false,
      effective_at: date + Employee::Balance::DAY_BEFORE_START_DAY_OFFSET,
      resource_amount: 0
    }
  end

  def validity_date_for_base_options(date, for_day_before)
    return RelatedPolicyPeriod.new(resource).validity_date_for(date) unless for_day_before
    RelatedPolicyPeriod.new(active_policy_at(date)).validity_date_for_balance_at(date)
  end

  def active_policy_at(date)
    employee.active_policy_in_category_at_date(resource.time_off_category_id, date)
  end

  def balance_is_not_assignation?(date)
    date != resource.effective_at
  end

  def calculate_effective_till
    effective_till = resource.effective_till
    if effective_till && effective_till <= future_policy_period_last_date
      effective_till
    else
      future_policy_period_last_date
    end
  end

  def future_policy_period_last_date
    @future_policy_period_last_date ||=
      EmployeePolicyPeriod.new(employee, resource.time_off_category_id).future_policy_period.last
  end
end
