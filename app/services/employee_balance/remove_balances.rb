class RemoveBalances
  attr_reader :time_off_category, :employee, :starting_date, :ending_date, :old_effective_at

  def initialize(time_off_category, employee, starting_date, ending_date, old_effective_at = nil)
    @time_off_category = time_off_category
    @employee = employee
    @starting_date = starting_date.to_date
    @ending_date = ending_date
    @old_effective_at = old_effective_at
  end

  def call
    day_before_start_dates_to_delete.map(&:delete)
    removals_to_delete.map(&:delete)
    additions_to_delete.map(&:delete)
  end

  private

  def day_before_start_dates_to_delete
    day_before_dates = additions_to_delete.map do |balance|
      balance.effective_at.to_date - 1.day + Employee::Balance::DAY_BEFORE_START_DAY_OFFSET
    end
    balances_day_before_assignations = assignation_balances.map do |balance|
      balance.effective_at.to_date - 1.day + Employee::Balance::DAY_BEFORE_START_DAY_OFFSET
    end
    balances_in_category.where(effective_at: day_before_dates + balances_day_before_assignations)
  end

  def removals_to_delete
    removals_with_additions_between_dates - removals_with_related_time_offs
  end

  def removals_with_additions_between_dates
    balances =
      removals_after_new_effective_at
      .where('balance_credit_additions.effective_at > ?', starting_date)
      .where.not(balance_credit_additions: { id: assignation_balances_ids })
    return balances unless ending_date.present?
    balances.where('balance_credit_additions.effective_at < ?', ending_date)
  end

  def removals_with_related_time_offs
    removals_after_new_effective_at.where(effective_at:
      balances_after_starting_date.where.not(time_off_id: nil).pluck(:validity_date))
  end

  def removals_after_new_effective_at
    @removals_after_new_effective_at ||=
      balances_after_starting_date.joins('
        INNER JOIN employee_balances AS balance_credit_additions
        ON balance_credit_additions.balance_credit_removal_id =
        employee_balances.id
      ')
  end

  def additions_to_delete
    balances = balances_after_starting_date.additions.not_time_off
    return balances - assignation_balances unless ending_date.present?
    balances.where('effective_at <= ?', ending_date) - assignation_balances
  end

  def assignation_balances_ids
    assignation_balances.pluck(:id)
  end

  def assignation_balances
    @assignation_balances ||= begin
      etop_effective_ats = etops_in_category.pluck(:effective_at).map do |date|
        "\'#{date + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET}\'"
      end.join(', ')

      clause_for_etops = "effective_at IN (#{etop_effective_ats})"

      if old_effective_at.present?
        date_with_offset = old_effective_at + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET
        clause_for_old_effective_at = "effective_at = \'#{date_with_offset}\'"
      end

      sql_where_clause =
        if etop_effective_ats.present? && old_effective_at.present?
          clause_for_etops + ' OR ' + clause_for_old_effective_at
        elsif etop_effective_ats.empty? && old_effective_at.present?
          clause_for_old_effective_at
        elsif etop_effective_ats.present? && old_effective_at.nil?
          clause_for_etops
        end

      balances_in_category.not_time_off.where(sql_where_clause)
    end
  end

  def balances_after_starting_date
    @balances_after_starting_date ||=
      balances_in_category.where('employee_balances.effective_at::date > ?', starting_date.to_date)
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
