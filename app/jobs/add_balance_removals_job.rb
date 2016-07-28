class AddBalanceRemovalsJob < ActiveJob::Base
  queue_as :policies_and_balances

  def perform
    Employee::Balance.where('validity_date IS NOT NULL').each do |balance|
      if balance.validity_date.to_date == Time.zone.today && balance.balance_credit_removal.blank?
        create_removal(balance)
      end
    end
  end

  private

  def create_removal(balance)
    category = balance.time_off_category_id
    employee = balance.employee_id
    account = balance.employee.account_id
    options = { balance_credit_addition_id: balance.id, amount: 0 }

    CreateEmployeeBalance.new(category, employee, account, options).call
  end

  def basic_params(balance)
    [balance.time_off_category_id, balance.employee_id, balance.employee.account_id]
  end
end
