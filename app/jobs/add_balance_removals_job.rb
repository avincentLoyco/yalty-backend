class AddBalanceRemovalsJob < ActiveJob::Base
  @queue = :add_balance_removals_job

  def perform
    Employee::Balance.where('validity_date IS NOT NULL').each do |balance|
      if balance.validity_date == Date.today
        create_removal(balance)
      end
    end
  end

  private

  def create_removal(balance)
    category, employee, account, amount, options =
      balance.time_off_category_id, balance.employee_id, balance.employee.account_id, 0,
      { balance_credit_addition_id: balance.id }

    CreateEmployeeBalance.new(category, employee, account, amount, options).call
  end

  def basic_params(balance)
    [balance.time_off_category_id, balance.employee_id, balance.employee.account_id]
  end
end
