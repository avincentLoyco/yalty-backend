class CreateEmployeeBalance
  include API::V1::Exceptions
  attr_reader :category, :employee, :params, :employee_balance, :time_off_policy

  def initialize(category, employee, policy, params)
    @category = category
    @employee = employee
    @params = params
    @time_off_policy = policy
    @employee_balance = nil
  end

  def call
    ActiveRecord::Base.transaction do
      find_time_off_policy if time_off_policy.blank? && related_present?
      find_or_build_employee_balance
      update_balance_attributes

      save!
    end
  end

  def related_present?
    employee.present? && category.present?
  end

  def find_time_off_policy
    @time_off_policy = employee.active_policy_in_category(category.id)
  end

  def find_or_build_employee_balance
    @employee_balance = Employee::Balance.where(
      id: params[:id], time_off_category: category, employee: employee).first_or_initialize
  end

  def update_balance_attributes
    employee_balance.tap do |balance|
      balance.amount = params[:amount]
      balance.time_off_policy = time_off_policy
    end
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
end
