namespace :update_and_create_missing_balances do
  desc 'Create missing assignation balances, update time offs effective at and update validity date'

  task update_and_create: :environment do
    ActiveRecord::Base.transaction do
      EmployeeTimeOffPolicy.all.each do |etop|
        change_effective_at_to_employee_hired_date(etop)

        update_or_create_assignation_balance(etop)
        create_missing_additions(etop) if etop.employee_balances.additions.blank?
      end
      balances_with_time_offs =
        Employee::Balance
        .where.not(time_off_id: nil)
        .order(:effective_at)
        .group_by { |balance| [balance[:employee_id], balance[:time_off_category_id]] }

      balances_with_time_offs.each do |_k, v|
        update_time_off_employee_balances(v)
      end
    end
  end

  def change_effective_at_to_employee_hired_date(etop)
    return unless etop.effective_at < etop.employee.hired_date
    assignation_balance = etop.policy_assignation_balance
    @manual_amount = assignation_balance.try(:manual_amount).to_i
    etop.update!(effective_at: etop.employee.hired_date)
    assignation_balance&.update!(effective_at: etop.employee.hired_date)
  end

  def remove_duplicated_employee_time_off_policies(etop)
    duplicated =
      etop
      .employee
      .employee_time_off_policies
      .where(time_off_category: etop.time_off_category, effective_at: etop.effective_at)
    return unless duplicated.size > 1
    older = duplicated.map(&:time_off_policy).sort_by { |policy| policy[:created_at] }.last
    duplicated.where(time_off_policy: older).first.destroy!
  end

  def update_or_create_assignation_balance(etop)
    if etop.policy_assignation_balance.present?
      etop.policy_assignation_balance.update!(
        validity_date: RelatedPolicyPeriod.new(etop).validity_date_for(etop.effective_at)
      )
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
    return unless first_start_date > etop.effective_at && first_start_date <= Time.zone.today
    ManageEmployeeBalanceAdditions.new(etop).call
  end

  def update_time_off_employee_balances(balances)
    balances.each do |balance|
      new_effective_at = balance.time_off.end_time
      active_policy = balance.employee.active_policy_in_category_at_date(
        balance.time_off_category_id,
        balance.time_off.end_time
      )
      validity_date = RelatedPolicyPeriod.new(active_policy).validity_date_for_time_off(
        balance.time_off.end_time
      )
      options = { validity_date: validity_date.to_s, effective_at: new_effective_at.to_s }

      if balance.id == balances.first.id
        ActiveRecord::Base.after_transaction do
          UpdateBalanceJob.perform_later(balance.id, options)
        end
      else
        UpdateEmployeeBalance.new(balance, options).call
      end
    end
  end
end
