class UpdateEtopForEvent
  include API::V1::Exceptions
  attr_accessor :event, :time_off_policy
  attr_reader :time_off_policy_amount, :old_effective_at, :etop

  def initialize(event_id, time_off_policy_days, old_effective_at)
    @event = Employee::Event.find(event_id)
    @time_off_policy_amount = time_off_policy_days * 1440
    @time_off_policy = find_time_off_policy(time_off_policy_amount)
    @old_effective_at = old_effective_at
    @etop = find_etop
  end

  def call
    return unless event && event_occupation_rate && etop
    update_occupation_rate
    update_time_off_policy
    recreate_balances
  end

  private

  def find_etop
    event_etops = event.employee_time_off_policies
    event_etops.detect { |etop| etop.time_off_category.name == 'vacation' }
  end

  def update_occupation_rate
    return unless event_occupation_rate != etop.occupation_rate
    etop.occupation_rate = event_occupation_rate
    etop.save!
  end

  def update_time_off_policy
    return unless etop.time_off_policy.amount != time_off_policy_amount
    if time_off_policy
      etop.time_off_policy_id = time_off_policy.id
      etop.save!
    else
      etop.time_off_policy_id = create_time_off_policy.id
    end
    attributes = {
      effective_at: etop.effective_at,
      effective_till: nil,
      employee_id: etop.employee_id,
      occupation_rate: event_occupation_rate,
      time_off_policy_id: time_off_policy.id,
      employee_event_id: event.id
    }
    CreateOrUpdateJoinTable.new(EmployeeTimeOffPolicy, TimeOffPolicy, attributes, etop).call
  end

  def find_time_off_policy(time_off_policy_amount)
    vacation_tops = TimeOffPolicy.all.select do |top|
      top.time_off_category.name == 'vacation' && !top.reset
    end
    vacation_tops.detect { |vacation_top| vacation_top.amount == time_off_policy_amount }
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

  def event_occupation_rate
    event.attribute_values['occupation_rate']
  end

  def recreate_balances
    RecreateBalances::AfterEmployeeTimeOffPolicyUpdate.new(
      new_effective_at: event.effective_at,
      old_effective_at: old_effective_at,
      time_off_category_id: time_off_policy.time_off_category_id,
      employee_id: event.employee_id,
      manual_amount: Adjustments::Calculate.new(event.employee_id).call
    ).call
  end
end
