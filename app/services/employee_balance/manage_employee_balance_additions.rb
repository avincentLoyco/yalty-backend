class ManageEmployeeBalanceAdditions
  attr_reader :resource, :employee, :effective_at, :balances, :effective_till, :update

  def initialize(resource, update = true)
    @update = update
    @resource = resource
    @employee = resource.employee
    @effective_at = resource.effective_at
    @effective_till = calculate_effective_till
    @balances = []
  end

  def call
    return if effective_till && RelatedPolicyPeriod.new(resource).first_start_date > effective_till
    ActiveRecord::Base.transaction do
      create_additions_with_removals
      balances = balances.flatten.compact if balances.present?
      if update && balances.present?
        PrepareEmployeeBalancesToUpdate.new(balances.first, update_all: true).call
      end
    end
    check_amount_and_update_balances
  end

  private

  def check_amount_and_update_balances
    return unless update && balances.flatten.present? && amount_affect_balances?
    ActiveRecord::Base.after_transaction do
      UpdateBalanceJob.perform_later(balances.flatten.first, update_all: true)
    end
  end

  def amount_affect_balances?
    balances.flatten.compact.map do |balance|
      [balance[:manual_amount], balance[:resource_amount]]
    end.flatten.uniq != [0]
  end

  def create_additions_with_removals
    etops_between_dates.each do |etop|
      create_employee_balance!(etop, etop.effective_at, 'assignation')

      balance_date = RelatedPolicyPeriod.new(etop).first_start_date
      date_to_which_create_balances = etop.effective_till || ending_date

      while balance_date <= date_to_which_create_balances
        balances << create_employee_balance!(etop, balance_date, 'addition')
        balances <<  create_end_of_period_balance!(etop, balance_date)
        balance_date += 1.year
      end
    end
  end

  def etops_between_dates
    @etops_between_dates =
      employee
      .employee_time_off_policies
      .where(time_off_category: resource.time_off_category)
      .where('effective_at BETWEEN ? AND ?', resource.effective_at, ending_date)
      .not_reset
  end

  def ending_date
    @ending_date = future_policy_period_last_date
    @ending_date.present? ? @ending_date : resource.effective_till
  end

  def create_end_of_period_balance!(etop, date)
    previous_policy = etop.previous_policy_for.try(:first)
    return unless date != etop.effective_at ||
        (previous_policy.present? && !previous_policy.related_resource.reset?)
    etop_for_end = date.eql?(etop.effective_at) ? previous_policy : etop
    create_employee_balance!(etop_for_end, date, 'end_of_period')
  end

  def balance_at_date(etop, date, balance_type)
    employee.employee_balances.find_by(
      'effective_at = ? AND time_off_category_id = ?',
      date + Employee::Balance.const_get("#{balance_type}_offset".upcase),
      etop.time_off_category_id
    )
  end

  def create_employee_balance!(etop, date, balance_type)
    return unless balance_at_date(etop, date, balance_type).nil?
    CreateEmployeeBalance.new(
      etop.time_off_category_id,
      etop.employee_id,
      employee.account_id,
      {
        skip_update: true,
        resource_amount: balance_type.eql?('addition') ? etop.time_off_policy.amount : 0,
        effective_at: date + Employee::Balance.const_get("#{balance_type}_offset".upcase),
        balance_type: balance_type
      }.merge(validity_date(etop, date, balance_type))
    ).call
  end

  def validity_date(etop, date, balance_type)
    return {} if etop.time_off_policy.counter?
    {
      validity_date: RelatedPolicyPeriod.new(etop).validity_date_for_balance_at(date, balance_type)
    }
  end

  def calculate_effective_till
    effective_till = resource.effective_till
    if effective_till && (future_policy_period_last_date.blank? ||
        effective_till <= future_policy_period_last_date)
      effective_till
    else
      future_policy_period_last_date
    end
  end

  def future_policy_period_last_date
    @future_policy_period_last_date ||=
      EmployeePolicyPeriod.new(employee, resource.time_off_category_id).future_policy_period&.last
  end
end
