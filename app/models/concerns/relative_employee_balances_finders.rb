module RelativeEmployeeBalancesFinders
  def balances
    self.class.employee_balances(employee_id, time_off_category_id)
  end

  def next_balance
    balances.where('effective_at > ?', now_or_effective_at).order(effective_at: :asc).first
  end

  def previous_balances
    balances.where('effective_at < ?', now_or_effective_at).order(effective_at: :asc)
  end

  def last_balance_after(addition)
    previous_balances.where('amount <= ? AND effective_at > ?', 0, addition.effective_at).last
  end

  def positive_balances_after(addition)
    balances.where(effective_at: addition.effective_at..now_or_effective_at,
                   amount: 1..Float::INFINITY, validity_date: nil).pluck(:amount).sum
  end

  def active_balances
    balances.where('effective_at < ? AND validity_date > ?', effective_at, effective_at)
  end

  def now_or_effective_at
    return effective_at if effective_at && balance_credit_addition.blank? && time_off.blank?
    if balance_credit_addition.try(:validity_date)
      balance_credit_addition.validity_date
    else
      time_off.try(:start_time) || Time.zone.now
    end
  end
end
