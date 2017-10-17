class CreateEtopForEvent
  include API::V1::Exceptions
  attr_accessor :event, :time_off_policy
  attr_reader :time_off_policy_amount

  def initialize(event_id, time_off_policy_days)
    @event = Employee::Event.find(event_id)
    @time_off_policy_amount = time_off_policy_days * 1440
    @time_off_policy = get_time_off_policy(time_off_policy_amount)
  end

  def call
    create_time_off_policy unless time_off_policy
    create_etop
    recreate_balances
  end

  private

  def get_time_off_policy(time_off_policy_amount)
    vacation_tops = event.employee.account.time_off_policies.all.select do |top|
      top.time_off_category.name == 'vacation' && !top.reset
    end
    vacation_tops.detect { |vacation_top| vacation_top.amount == time_off_policy_amount }
  end

  def create_etop
    attributes = {
      effective_at: event.effective_at,
      effective_till: nil,
      employee_id: event.employee_id,
      occupation_rate: event.attribute_values['occupation_rate'],
      time_off_policy_id: time_off_policy.id,
      employee_event_id: event.id
    }
    CreateOrUpdateJoinTable.new(EmployeeTimeOffPolicy, TimeOffPolicy, attributes).call
  end

  def create_time_off_policy
    days_off = time_off_policy_amount / 60.0 / 24.0
    @time_off_policy = TimeOffPolicy.create!(
      start_day: 1,
      start_month: 1,
      end_day: nil,
      end_month: nil,
      amount: time_off_policy_amount,
      years_to_effect: 0,
      policy_type: 'balancer',
      time_off_category_id: event.employee.account.time_off_categories.find_by(name: 'vacation').id,
      name: "Time Off Policy #{days_off}",
      reset: false
    )
  end

  def recreate_balances
    RecreateBalances::AfterEmployeeTimeOffPolicyCreate.new(
      new_effective_at: event.effective_at,
      time_off_category_id: time_off_policy.time_off_category_id,
      employee_id: event.employee_id,
      manual_amount: Adjustments::Calculate.new(event.employee_id).call
    ).call
  end
end
