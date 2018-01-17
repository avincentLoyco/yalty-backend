desc 'Fix balances for banque-du-leman account'
task fix_banque_du_leman: :environment do
  account = Account.find_by(subdomain: 'banque-du-leman')
  time_off_policies = account.time_off_policies.where(active: false, reset: false)
  time_off_policies.each do |time_off_policy|
    new_time_off_policy = time_off_policy.dup
    new_time_off_policy.update(end_day: 1, end_month: 1, years_to_effect: 1)
    new_time_off_policy.save!
    time_off_policy.employee_time_off_policies.each do |etop|
      etop.update(time_off_policy_id: new_time_off_policy.id)
      etop.save!
      RecreateBalances::AfterEmployeeTimeOffPolicyUpdate.new(
        new_effective_at: etop.effective_at,
        old_effective_at: etop.effective_at,
        time_off_category_id: etop.time_off_category_id,
        employee_id: etop.employee_id,
        manual_amount: 0
      ).call
    end
    time_off_policy.destroy!
  end
end
