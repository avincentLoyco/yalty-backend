task recreate_balances: [:environment] do
  EmployeeTimeOffPolicy.order(:effective_at).each do |etop|
    new_effective_at = etop.effective_at
    old_effective_at = etop.effective_at

    manual_amount = etop.policy_assignation_balance.try(:manual_amount).to_i
    if etop.effective_at < etop.employee.hired_date
      params = {
        time_off_policy_id: etop.time_off_policy_id,
        employee_id: etop.employee.id,
        effective_at: etop.employee.hired_date
      }
      response = CreateOrUpdateJoinTable.new(
        EmployeeTimeOffPolicy, TimeOffPolicy, params, etop
      ).call
      new_effective_at = response[:result].effective_at
    end

    RecreateBalances::AfterEmployeeTimeOffPolicyUpdate.new(
      new_effective_at: new_effective_at,
      old_effective_at: old_effective_at,
      time_off_category_id: etop.time_off_category_id,
      employee_id: etop.employee_id,
      manual_amount: manual_amount
    ).call
  end
end
