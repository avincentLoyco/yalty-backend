class CreateEtopForEvent
  include API::V1::Exceptions
  attr_accessor :event, :etop
  attr_reader :time_off_policy_amount

  def initialize(event_id, time_off_policy_amount)
    @event                  = Employee::Event.find(event_id)
    @time_off_policy_amount = time_off_policy_amount
  end

  def call
    create_etop
    recreate_balances
  end

  private

  def create_etop
    @etop = EmployeePolicy::TimeOff::Create.call(event.id, time_off_policy_amount)
  end

  def recreate_balances
    RecreateBalances::AfterEmployeeTimeOffPolicyCreate.new(
      new_effective_at: event.effective_at,
      time_off_category_id: etop.time_off_policy.time_off_category_id,
      employee_id: event.employee_id,
      manual_amount: Adjustments::Calculate.new(event.id).call
    ).call
  end
end
