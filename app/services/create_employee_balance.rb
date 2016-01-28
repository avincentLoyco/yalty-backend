class CreateEmployeeBalance
  include API::V1::Exceptions
  attr_reader :category, :employee, :amount, :employee_balance, :account, :time_off, :options

  def initialize(category_id, employee_id, account_id, amount, options = {})
    @options = options
    @account = Account.find(account_id)
    @category = account.time_off_categories.find(category_id)
    @employee = account.employees.find(employee_id)
    @amount = amount
    @employee_balance = nil
    @time_off = find_time_off
  end

  def call
    ActiveRecord::Base.transaction do
      build_employee_balance if related_present?
      save!

      update_next_employee_balances
    end
    employee_balance
  end

  def find_time_off_policy
    @time_off_policy = employee.active_policy_in_category(category.id)
  end

  def build_employee_balance
    @employee_balance = Employee::Balance.new(
      amount: amount,
      employee: employee,
      time_off: time_off,
      time_off_category: category,
      time_off_policy: time_off_policy,
      policy_credit_addition: policy_credit_addition,
      policy_credit_removal: policy_credit_removal,
      effective_at: effective_at
    )
  end

  def save!
    if employee_balance.valid?
      employee_balance.save!
      employee_balance
    else
      messages = employee_balance.errors.messages

      fail InvalidResourcesError.new(employee_balance, messages)
    end
  end

  private

  def related_present?
    account.present? && employee.present? && category.present?
  end

  def find_time_off
    return nil unless options.has_key?(:time_off_id)
    employee.time_offs.find(options.delete(:time_off_id))
  end

  def effective_at
    return nil unless options.has_key?(:effective_at) || time_off
    time_off ? time_off.start_time : options.delete(:effective_at)
  end

  def time_off_policy
    employee.active_policy_in_category(category.id)
  end

  def policy_credit_addition
    options.delete(:policy_credit_addition)
  end

  def policy_credit_removal
    options.delete(:policy_credit_removal)
  end

  def update_next_employee_balances
    return if employee_balance.last_in_category?
    balances_ids = employee_balance.later_balances_ids
    update_beeing_processed_status(balances_ids)
    UpdateBalanceJob.perform_later(employee_balance.id)
  end

  def update_beeing_processed_status(balances_ids)
    Employee::Balance.where(id: balances_ids).update_all(beeing_processed: true)
    TimeOff.find(time_off.id).update(beeing_processed: true) if time_off
  end
end
