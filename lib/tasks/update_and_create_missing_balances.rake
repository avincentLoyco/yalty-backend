namespace :update_and_create_missing_balances do
  desc 'Create missing assignation balances, update time offs effective at and update validity date'

  task update_and_create: :environment do
    EmployeeTimeOffPolicy.all.each do |etop|
      destroyed = remove_duplicated_employee_time_off_policies(etop) unless etop.valid?
      next unless etop.valid? && (destroyed.nil? || destroyed.id != etop.id)
      change_effective_at_to_employee_hired_date(etop)

      update_or_create_assignation_balance(etop)
      create_missing_additions(etop) if etop.employee_balances.additions.blank?
    end
    ActiveRecord::Base.connection.execute("""
      UPDATE employee_balances SET effective_at = (
        SELECT time_offs.end_time FROM time_offs
        WHERE time_offs.id = employee_balances.time_off_id
      ) WHERE employee_balances.time_off_id IS NOT NULL;
    """)
    Employee::Balance.where.not(time_off_id: nil).each do |balance|
      update_time_off_employee_balances(balance)
    end
  end

  def change_effective_at_to_employee_hired_date(etop)
    return unless etop.effective_at < etop.employee.hired_date
    assignation_balance = etop.policy_assignation_balance
    @manual_amount = assignation_balance.try(:manual_amount).to_i
    etop.update!(effective_at: etop.employee.hired_date)
    assignation_balance.update!(effective_at: etop.employee.hired_date) if assignation_balance
  end

  def remove_duplicated_employee_time_off_policies(etop)
    duplicated =
      etop
      .employee
      .employee_time_off_policies
      .where(time_off_category: etop.time_off_category, effective_at: etop.effective_at)
    if duplicated.size > 1
      older = duplicated.map(&:time_off_policy).sort_by { |policy| policy[:created_at] }.last
      duplicated.where(time_off_policy: older).first.destroy!
    end
  end

  def update_or_create_assignation_balance(etop)
    if etop.policy_assignation_balance.present?
      etop.policy_assignation_balance.update!(
        validity_date: RelatedPolicyPeriod.new(etop).validity_date_for(etop.effective_at))
    else
      CreateEmployeeBalance.new(
        etop.time_off_category.id,
        etop.employee.id,
        etop.employee.account.id,
        effective_at: etop.effective_at + 5.minutes,
        manual_amount: @manual_amount ? @manual_amount : 0,
        validity_date: RelatedPolicyPeriod.new(etop).validity_date_for(etop.effective_at),
        skip_update: true
      ).call
    end
  end

  def create_missing_additions(etop)
    first_start_date = RelatedPolicyPeriod.new(etop).first_start_date
    if first_start_date > etop.effective_at && first_start_date <= Date.today
      ManageEmployeeBalanceAdditions.new(etop).call
    end
  end

  def update_time_off_employee_balances(balance)
    active_policy = balance.employee.active_policy_in_category_at_date(
      balance.time_off_category_id,
      balance.time_off.end_time
    )
    validity_date = RelatedPolicyPeriod.new(active_policy).validity_date_for_time_off(
      balance.time_off.end_time
    )
    UpdateEmployeeBalance.new(balance, validity_date: validity_date).call
  end
end
