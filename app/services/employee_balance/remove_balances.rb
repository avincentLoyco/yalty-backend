class RemoveBalances
  attr_reader :time_off_category, :employee, :starting_date, :ending_date, :old_effective_at

  def initialize(time_off_category, employee, starting_date, ending_date, old_effective_at = nil)
    @time_off_category = time_off_category
    @employee = employee
    @starting_date = starting_date
    @ending_date = ending_date
    @old_effective_at = old_effective_at
  end

  def call
    (day_before_start_dates_to_delete + removals_to_delete + additions_to_delete).map(&:delete)
  end

  private

  def day_before_start_dates_to_delete
    balances = balances_after_starting_date.where(policy_credit_addition: false).not_time_off
    balances = balances.where('effective_at < ?', ending_date) if ending_date.present?
    balances - removals_after_new_effective_at - assignation_balances
  end

  def removals_to_delete
    removals_with_additions_between_dates - removals_with_related_time_offs
  end

  def removals_with_additions_between_dates
    balances = removals_after_new_effective_at.where('
      balance_credit_additions.effective_at > ? AND
      balance_credit_additions.policy_credit_addition = true', starting_date)
    return balances unless ending_date.present?
    balances.where('balance_credit_additions.effective_at < ?', ending_date)
  end

  def removals_with_related_time_offs
    removals_after_new_effective_at.where(effective_at:
      balances_after_starting_date.where.not(time_off_id: nil).pluck(:validity_date))
  end

  def removals_after_new_effective_at
    @removals_after_new_effective_at ||=
      balances_after_starting_date.removals.joins('
        INNER JOIN employee_balances AS balance_credit_additions
        ON balance_credit_additions.balance_credit_removal_id =
        employee_balances.id
      ')
  end

  def additions_to_delete
    balances = balances_after_starting_date.additions.not_time_off
    return balances unless ending_date.present?
    balances.where('effective_at <= ?', ending_date) - assignation_balances
  end

  def assignation_balances
    return [] unless etops_in_category.exists?
    @assignation_balances ||= begin
      etop_effective_ats = etops_in_category.pluck(:effective_at)
                                            .map { |date| "\'#{date}\'::date" }.join(', ')
      sql_where_clause = "effective_at::date IN (#{etop_effective_ats})"
      if old_effective_at.present?
        sql_where_clause += " OR effective_at::date = \'#{old_effective_at.to_date}\'::date"
      end
      balances_in_category.not_time_off.where(sql_where_clause)
    end
  end

  def balances_after_starting_date
    @balances_after_starting_date ||=
      balances_in_category.where('employee_balances.effective_at > ?', starting_date)
  end

  def etops_in_category
    employee
      .employee_time_off_policies
      .where(time_off_category: time_off_category)
      .order(:effective_at)
  end

  def balances_in_category
    employee.employee_balances.where(time_off_category: time_off_category)
  end
end
