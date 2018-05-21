class UpdateEtopForEvent
  include API::V1::Exceptions
  attr_accessor :event, :etop, :time_off_policy
  attr_reader :time_off_policy_amount, :old_effective_at

  def initialize(event_id, time_off_policy_amount, old_effective_at)
    @event                  = Employee::Event.find(event_id)
    @time_off_policy_amount = time_off_policy_amount
    @old_effective_at       = old_effective_at
    @etop                   = event.employee_time_off_policy
  end

  def call
    return unless event && event_occupation_rate

    @etop ||= EmployeePolicy::TimeOff::Create.call(event.id, time_off_policy_amount)
    @time_off_policy = Policy::TimeOff::FindOrCreateByAmount.call(time_off_policy_amount,
      event.employee.account.id)

    update_effective_at
    update_occupation_rate
    update_time_off_policy
    recreate_balances
  end

  private

  def update_effective_at
    return unless event && etop
    etop.effective_at = event.effective_at
    etop.save!
  end

  def update_occupation_rate
    return unless event_occupation_rate != etop.occupation_rate
    etop.occupation_rate = event_occupation_rate
    etop.save!
  end

  def update_time_off_policy
    return unless etop.time_off_policy.amount != time_off_policy_amount
    etop.time_off_policy_id = time_off_policy.id
    etop.save!
    attributes = {
      effective_at: etop.effective_at,
      effective_till: nil,
      employee_id: etop.employee_id,
      occupation_rate: event_occupation_rate,
      time_off_policy_id: time_off_policy.id,
      employee_event_id: event.id,
    }
    CreateOrUpdateJoinTable.new(EmployeeTimeOffPolicy, TimeOffPolicy, attributes, etop).call
  end

  def event_occupation_rate
    event.attribute_value("occupation_rate")
  end

  def recreate_balances
    RecreateBalances::AfterEmployeeTimeOffPolicyUpdate.new(
      new_effective_at: event.effective_at,
      old_effective_at: old_effective_at,
      time_off_category_id: time_off_policy.time_off_category_id,
      employee_id: event.employee_id,
      manual_amount: Adjustments::Calculate.new(event.id).call
    ).call
  end
end
