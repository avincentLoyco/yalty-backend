module EmployeeBalancesPresenceVerification
  def verify_if_there_are_no_balances!
    return unless balances_after_effective_at.present?
    raise ActiveRecord::RecordNotDestroyed,
      "Record can not be removed, there are employee balances after effective at."
  end

  def balances_after_effective_at
    balances =
      resource.employee.employee_balances.where("effective_at >= ?", resource.effective_at)

    return balances unless resource.class.eql?(EmployeeTimeOffPolicy)
    balances.where(time_off_category: resource.time_off_category)
  end
end
