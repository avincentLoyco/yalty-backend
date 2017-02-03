task add_missing_manual_amounts: [:environment] do
  missing_balances_data = eval(File.read('missing_balances_data.rb'))
  return unless missing_balances_data.is_a?(Array)

  ActiveRecord::Base.transaction do
    balances = []

    missing_balances_data.each do |employee_id, effective_at, etop_id, manual_amount|
      etop = EmployeeTimeOffPolicy.where(id: etop_id, employee_id: employee_id).first
      next unless etop.present?

      balance = balance_for(employee_id, etop, effective_at)
      next if balance.nil? || balance.manual_amount.eql?(manual_amount)
      balances << balance.tap { |b| b.update!(manual_amount: manual_amount) }
    end

    balances.map do |balance|
      PrepareEmployeeBalancesToUpdate.new(balance, update_all: true).call
      UpdateBalanceJob.perform_later(balance.id, update_all: true)
    end
  end
end

def balance_for(employee_id, etop, effective_at)
  balance =
    Employee::Balance
    .employee_balances(employee_id, etop.time_off_category_id)
    .where(effective_at: Time.parse(effective_at).utc)
    .first

  return balance if balance.present?
  etop.policy_assignation_balance
end
