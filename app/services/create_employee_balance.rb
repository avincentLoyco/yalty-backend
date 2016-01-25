class CreateEmployeeBalance
  include API::V1::Exceptions
  attr_reader :category, :employee, :amount,
    :employee_balance, :time_off_policy, :account, :time_off

  def initialize(category_id, employee_id, account_id, amount, time_off_id)
    @account = Account.find(account_id)
    @category = account.time_off_categories.find(category_id)
    @employee = account.employees.find(employee_id)
    @time_off = employee.time_offs.find(time_off_id) if (employee && time_off_id)
    @amount = amount
    @time_off_policy = nil
    @employee_balance = nil
  end

  def call
    ActiveRecord::Base.transaction do
      find_time_off_policy if related_present?
      build_employee_balance

      save!
    end
  end

  def related_present?
    account.present? && employee.present? && category.present?
  end

  def find_time_off_policy
    @time_off_policy = employee.active_policy_in_category(category.id)
  end

  def build_employee_balance
    @employee_balance = Employee::Balance.new(
      time_off_category: category,
      time_off_policy: time_off_policy,
      amount: amount,
      employee: employee,
      time_off: time_off)
  end

  def save!
    if employee_balance.valid?
      employee_balance.save!
    else
      messages = employee_balance.errors.messages

      fail InvalidResourcesError.new(employee_balance, messages)
    end
  end
end
