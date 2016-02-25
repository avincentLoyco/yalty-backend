module RelativeEmployeeBalancesFinders
  def balances
    self.class.employee_balances(employee_id, time_off_policy_id)
  end

  def next_balance
    balances.where('effective_at > ?', now_or_effective_at).order(effective_at: :asc).first.try(:id)
  end

  def next_removal
    balances.where('policy_credit_removal = true AND effective_at > ?', effective_at)
      .order(effective_at: :asc).first
  end

  def previous_balances
    balances.where('effective_at < ?', now_or_effective_at).order(effective_at: :asc)
  end

  def last_balance(addition)
    previous_balances.where('amount <= ? AND effective_at > ?', 0, addition.effective_at).last
  end

  def positive_balances(addition)
    balances.where(effective_at: addition.effective_at..now_or_effective_at,
      amount: 1..Float::INFINITY, validity_date: nil).pluck(:amount).sum
  end

  def active_balances
    balances.where('effective_at < ? AND validity_date > ?', effective_at, effective_at)
  end

  def active_balances_with_removals
    return [] unless active_balances.present?
    balances.where(id: balances.where(balance_credit_addition_id: active_balances.pluck(:id))
      .pluck(:balance_credit_addition_id))
  end

  def later_balances_ids
    return nil unless time_off_policy
    time_off_policy.counter? ? find_ids_for_counter : find_ids_for_balancer
  end

  def find_ids_for_counter
    return all_later_ids if current_or_next_period || next_removal.blank?
    balances.where(effective_at: effective_at..next_removal.effective_at).pluck(:id)
  end

  def find_ids_for_balancer
    current_or_next_period && active_balances_with_removals.blank? ||
      active_balances_with_removals.blank? && policy_end_dates_blank? ||
      next_removals_smaller_than_amount? ? all_later_ids : ids_to_removal
  end

  def all_later_ids(effective = effective_at)
    balances.where("effective_at >= ?", effective).pluck(:id)
  end

  def ids_to_removal
    removals = balances.where(balance_credit_addition_id: active_balances.pluck(:id))
      .order(effective_at: :asc)
    new_amount = amount

    removals.each do |removal|
      new_amount = new_amount - removal.amount unless removal.amount.abs >= new_amount.abs
      return balances.where(effective_at: effective_at..removal.effective_at).pluck(:id)
    end
  end

  def now_or_effective_at
    effective_at || Time.now
  end
end
