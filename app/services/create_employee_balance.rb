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
      find_or_build_employee_balance
      find_time_off_policy unless time_off_policy
      update_balance_attributes if time_off_policy

      save!
    end
  end

  def find_or_build_employee_balance
    @employee_balance = employee.employee_balances
      .where(id: params[:id], time_off_category: category).first_or_initialize
  end

  def find_time_off_policy
    @time_off_policy = employee.active_policy_in_category(category.id)
  end

  def update_balance_attributes
    employee_balance.tap do |e|
      e.amount = params[:amount]
      e.time_off_policy = time_off_policy
    end
  end

  def save!
    if employee_balance.valid?
      employee_balance.save!
      employee_balance
    else
      messages = {}
      messages = messages.merge(employee_balance.errors.messages)

      fail InvalidResourcesError.new(employee_balance, messages)
    end
  end
end
