class AddBalanceRemovalsJob < ActiveJob::Base
  queue_as :policies_and_balances

  def perform
    expiring_balances_by_employee_and_category =
      Employee::Balance
      .where('validity_date::date = ?', Time.zone.today)
      .group_by { |balance| [balance[:employee_id], balance[:time_off_category_id]] }

    expiring_balances_by_employee_and_category.each do |_k, v|
      create_removal(v)
    end
  end

  private

  def create_removal(balances)
    CreateEmployeeBalance.new(
      balances.first.time_off_category_id,
      balances.first.employee_id,
      balances.first.employee.account_id,
      balance_credit_additions: balances,
      validity_date: Time.zone.today
    ).call
  end
end
