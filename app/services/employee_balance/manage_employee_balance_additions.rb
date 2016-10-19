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
      PrepareEmployeeBalancesToUpdate.new(balances.flatten.first).call
    end
    check_amount_and_update_balances
  end

  private

  def check_amount_and_update_balances
    unless balances.flatten.map { |b| [b[:manual_amount], b[:resource_amount]] }.flatten.uniq == [0]
      ActiveRecord::Base.after_transaction do
        UpdateBalanceJob.perform_later(balances.flatten.first)
      end
    end
  end

  def create_additions_with_removals
    date = RelatedPolicyPeriod.new(resource).first_start_date
    while date <= effective_till
      balances << CreateEmployeeBalance.new(*employee_balance_params(date)).call
      if active_policy_at(date - 1.day).present? && balance_is_not_assignation(date)
        balances << CreateEmployeeBalance.new(*employee_balance_params(date - 1.day, true)).call
      end
      date += 1.year
    end
  end

  def employee_balance_params(date, for_day_before = false)
    [
      resource.time_off_category_id,
      resource.employee_id,
      employee.account_id,
      policy_type_options(date, for_day_before)
    ]
  end

  def policy_type_options(date, for_day_before)
    base_options =
      if for_day_before
        options_for_day_before_start_date(date)
      else
        default_options(date)
      end
    return base_options if resource.time_off_policy.counter?
    base_options.merge(validity_date: validity_date_for_base_options(date, for_day_before))
  end

  def default_options(date)
    {
      skip_update: true,
      policy_credit_addition: true,
      effective_at: date + 5.minutes,
      resource_amount: resource.time_off_policy.amount
    }
  end

  def options_for_day_before_start_date(date)
    {
      skip_update: true,
      policy_credit_addition: false,
      effective_at: date,
      resource_amount: 0
    }
  end

  def validity_date_for_base_options(date, for_day_before)
    return RelatedPolicyPeriod.new(resource).validity_date_for(date) unless for_day_before
    RelatedPolicyPeriod.new(active_policy_at(date)).validity_date_for_day_before_start_date(date)
  end

  def active_policy_at(date)
    employee.active_policy_in_category_at_date(resource.time_off_category_id, date)
  end

  def balance_is_not_assignation(date)
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
    EmployeePolicyPeriod.new(employee, resource.time_off_category_id).future_policy_period.last
  end
end
