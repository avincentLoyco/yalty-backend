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
    unless balances.flatten.map { |b| [b[:manual_amount], b[:resource_amount]] }.flatten.uniq == [0]
      UpdateBalanceJob.perform_later(balances.flatten.first)
    end
  end

  private

  def create_additions_with_removals
    date = RelatedPolicyPeriod.new(resource).first_start_date
    while date <= effective_till
      balances << CreateEmployeeBalance.new(*employee_balance_params(date)).call
      date += 1.year
    end
  end

  def employee_balance_params(date)
    [
      resource.time_off_category_id,
      resource.employee_id,
      employee.account_id,
      policy_type_options(date)
    ]
  end

  def policy_type_options(date)
    base_options =
      { skip_update: true, policy_credit_addition: true, effective_at: date + 5.minutes,
        resource_amount: resource.time_off_policy.amount }
    return base_options if resource.time_off_policy.counter?
    base_options.merge(validity_date: RelatedPolicyPeriod.new(resource).validity_date_for(date))
  end

  def calculate_effective_till
    effective_till = resource.effective_till
    effective_till && effective_till <= Time.zone.today ? effective_till : Time.zone.today
  end
end
