namespace :db do
  namespace :cleanup do
    task update_validity_dates: [:environment] do
      Employee.all.find_each do |employee|
        next unless employee.employee_balances.present?
        grouped_balances(employee).each do |_k, v|
          updated = v.map do |balance|
            next if balance.balance_credit_additions.present? ||
                (validity_date(balance).eql?(balance.validity_date) &&
                balance_has_removal?(balance))
            UpdateEmployeeBalance.new(balance, validity_date: validity_date(balance)).call
            balance
          end.flatten.compact
          next unless updated.present?
          UpdateBalanceJob.perform_later(updated.first.id, update_all: true)
        end
      end
    end

    def grouped_balances(employee)
      employee.employee_balances.not_removals.order(:effective_at).group_by(&:time_off_category_id)
    end

    def validity_date(balance)
      RelatedPolicyPeriod
        .new(balance.employee_time_off_policy)
        .validity_date_for(balance.effective_at)
    end

    def balance_has_removal?(balance)
      (balance.validity_date.nil? && balance.balance_credit_removal_id.nil?) ||
        (balance.validity_date.present? && balance.balance_credit_removal_id.present? &&
          balance.validity_date.eql?(balance.balance_credit_removal.try(:effective_at)))
    end
  end
end
