task update_order_of_start_days: [:environment] do
  EmployeePresencePolicy.where(presence_policy_id: seven_days_policies_ids).each do |epp|
    valid_order = epp.effective_at.wday.to_s.tr('0', '7').to_i

    next if valid_order.to_i.eql?(epp.order_of_start_day)
    epp.update!(order_of_start_day: valid_order)

    update_employee_balances_after_effective_at(epp)
  end
end

def update_employee_balances_after_effective_at(epp)
  grouped_balances_after_epp_effective_at(epp).map do |_k, v|
    PrepareEmployeeBalancesToUpdate.new(v.first, update_all: true).call
    UpdateBalanceJob.perform_later(v.first.id, update_all: true)
  end
end

def grouped_balances_after_epp_effective_at(epp)
  Employee
    .find(epp.employee.id)
    .employee_balances
    .where('effective_at >= ?', epp.effective_at)
    .order(:effective_at)
    .group_by { |balance| balance[:time_off_category_id] }
end

def seven_days_policies_ids
  PresencePolicy
    .joins(:presence_days)
    .group('presence_policies.id')
    .having('count( presence_policy_id) = 7')
    .pluck(:id)
end
