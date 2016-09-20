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
    CreateEmployeeBalance.new(
      balance.time_off_category_id,
      balance.employee_id,
      balance.employee.account_id,
      balance_credit_addition_id: balance.id, validity_date: Time.zone.today
    ).call
  end
end
