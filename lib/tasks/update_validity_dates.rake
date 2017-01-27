task update_validity_dates: [:environment] do
  Employee.all.each do |employee|
    next unless employee.employee_balances.present?
    grouped_balances(employee).each do |_k, v|
      updated = v.map do |balance|
        next if balance.balance_credit_additions.present? ||
            validity_date(balance).eql?(balance.validity_date)
        UpdateEmployeeBalance.new(balance, validity_date: validity_date(balance)).call
        balance
      end.flatten.compact
      next unless updated.present?
      UpdateBalanceJob.perform_later(updated.first.id, update_all: true)
    end
  end
end

def grouped_balances(employee)
  employee.employee_balances.order(:effective_at).group_by(&:time_off_category_id)
end

def validity_date(balance)
  RelatedPolicyPeriod.new(balance.employee_time_off_policy).validity_date_for(balance.effective_at)
end
