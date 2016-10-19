class RecreateBalances
  attr_reader(
    :new_effective_at,
    :old_effective_at,
    :time_off_category,
    :employee,
    :etop
  )

  def initialize(
      new_effective_at: nil,
      old_effective_at: nil,
      destroyed_effective_at: nil,
      time_off_category_id:,
      employee_id:
    )

    @new_effective_at = new_effective_at || destroyed_effective_at
    @old_effective_at = old_effective_at || destroyed_effective_at
    @etop = EmployeeTimeOffPolicy.find_by(effective_at: new_effective_at)
    @time_off_category = TimeOffCategory.find(time_off_category_id)
    @employee = Employee.find(employee_id)
  end

  def after_etop_create
    if balances_after_starting_point.present? || new_etop_first_in_category?
      remove_balances!
      recreate_and_recalculate_balances!
    end
  end

  def after_etop_update_to_past
    if balances_after_starting_point.present?
      remove_balances!
      remove_balance_at_old_effective_at!
      recreate_and_recalculate_balances!
    end
  end

  def after_etop_update_to_future
    remove_balances!
    remove_balance_at_old_effective_at!
    recreate_and_recalculate_balances!
  end

  def after_etop_destroy
    remove_balances!
    remove_balance_at_old_effective_at!
    return unless other_etops_in_category.exists?
    recreate_and_recalculate_balances!
  end

  private

  def remove_balances!
    (day_before_start_dates_to_delete + removals_to_delete + additions_to_delete).map(&:delete)
  end

  def remove_balance_at_old_effective_at!
    balance_to_remove = employee.employee_balances.find_by(effective_at: old_effective_at) ||
      employee.employee_balances.find_by(effective_at: old_effective_at + 5.minutes)
    return if !balance_to_remove.present?
    balance_to_remove.delete
  end

  def recreate_and_recalculate_balances!
    recreate_balances!
    recalculate_balances!
  end

  def day_before_start_dates_to_delete
    balances = balances_after_starting_point.where(policy_credit_addition: false).not_time_off
    balances = balances.where('effective_at < ?', ending_point) if ending_point.present?
    balances - removals_after_new_effective_at - assignation_balances
  end

  def removals_to_delete
    removals_with_additions_between_points - removals_with_related_time_offs
  end

  def additions_to_delete
    balances = balances_after_starting_point.additions.not_time_off
    return balances unless ending_point.present?
    balances.where('effective_at <= ?', ending_point) - assignation_balances
  end

  def removals_with_additions_between_points
    balances = removals_after_new_effective_at.where('
      balance_credit_additions.effective_at > ? AND
      balance_credit_additions.policy_credit_addition = true', starting_point
    )
    return balances unless ending_point.present?
    balances.where('balance_credit_additions.effective_at < ?', ending_point)
  end

  def removals_with_related_time_offs
    removals_after_new_effective_at.where(effective_at:
      balances_after_starting_point.where.not(time_off_id: nil).pluck(:validity_date)
    )
  end

  def removals_after_new_effective_at
    @removals_after_new_effective_at ||=
      balances_after_starting_point.removals.distinct.joins('
        LEFT JOIN employee_balances AS balance_credit_additions
        ON balance_credit_additions.balance_credit_removal_id =
        employee_balances.id
      ')
  end

  def assignation_balances
    return [] unless other_etops_in_category.exists?
    etop_effective_ats = employee
      .employee_time_off_policies
      .where(time_off_category: time_off_category)
      .pluck(:effective_at)
      .map { |date| "\'#{date}\'::date" }.join(', ')
    sql_where_clause = "effective_at::date IN (#{etop_effective_ats})"
    if try(:old_effective_at).present?
      sql_where_clause += " OR effective_at::date = \'#{old_effective_at.to_date}\'::date"
    end
    @assignation_balances ||=
      employee.employee_balances.where(sql_where_clause)
  end

  def balances_after_starting_point
    @balances_after_starting_point ||=
      employee.employee_balances.where('employee_balances.effective_at > ?', starting_point)
  end

  def recreate_balances!
    create_balance_for_new_or_updated_etop! if etop.present?
    manage_additions!
  end

  def create_balance_for_new_or_updated_etop!
    CreateEmployeeBalance.new(time_off_category.id, employee.id, employee.account.id,
      effective_at: new_effective_at,
      validity_date: RelatedPolicyPeriod.new(etop).validity_date_for(new_effective_at)
    ).call
  end

  def manage_additions!
    return ManageEmployeeBalanceAdditions.new(etop).call unless old_effective_at.present?
    manage_additions_for_etops_between_points!
  end

  def manage_additions_for_etops_between_points!
    end_effective_at = new_effective_at > old_effective_at ? new_effective_at : old_effective_at
    etops = employee
      .employee_time_off_policies
      .where(time_off_category: time_off_category)
      .where('effective_at BETWEEN ? AND ?', starting_point, ending_point || end_effective_at
    )
    etops.each { |etop_between| ManageEmployeeBalanceAdditions.new(etop_between).call }
  end

  def recalculate_balances!
    balance = balance_at_starting_point_or_first_balance
    PrepareEmployeeBalancesToUpdate.new(balance).call
    UpdateBalanceJob.perform_later(balance.id, update_all: true)
  end

  def balance_at_starting_point_or_first_balance
    Employee::Balance.find_by(effective_at: starting_point) ||
      Employee::Balance.find_by(effective_at: starting_point - 5.minutes) ||
      Employee::Balance.find_by(effective_at: starting_point + 5.minutes) ||
      Employee::Balance.find_by(
        effective_at: employee.employee_time_off_policies
                      .where(time_off_category: time_off_category)
                      .order(:effective_at).first.effective_at
      )
  end

  def starting_point
    @starting_point ||= if old_effective_at.nil? || old_effective_at > new_effective_at
      new_effective_at
    else
      effective_at_of_first_etop_before_moved_etop + 5.minutes
    end
  end

  def effective_at_of_first_etop_before_moved_etop
    before_etop = employee.employee_time_off_policies
      .where(time_off_category: time_off_category)
      .where('effective_at < ?', old_effective_at)
      .order(:effective_at)
      .last
    return old_effective_at unless before_etop.present?
    before_etop.effective_at
  end

  def ending_point
    return etop.try(:effective_till) unless old_effective_at.present?
    date_in_future = new_effective_at > old_effective_at ? new_effective_at : old_effective_at
    first_etop_after_date_in_future = employee.employee_time_off_policies
      .where(time_off_category: time_off_category)
      .where('effective_at > ?', date_in_future).order(:effective_at).first
    return unless first_etop_after_date_in_future.present?
    first_etop_after_date_in_future.effective_at - 1.day
  end

  def other_etops_in_category
    employee
      .employee_time_off_policies
      .where(time_off_category: time_off_category)
  end

  def new_etop_first_in_category?
    other_etops_in_category.count == 1
  end
end
