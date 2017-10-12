class HandleEppForEvent
  include API::V1::Exceptions
  attr_reader :event, :presence_policy

  def initialize(event_id, presence_policy_id)
    @event           = Employee::Event.find(event_id)
    @presence_policy = PresencePolicy.find(presence_policy_id)
  end

  def call
    verify_proper_occupation_rate
    CreateOrUpdateJoinTable.new(EmployeePresencePolicy, PresencePolicy, attributes).call
  end

  private

  def verify_proper_occupation_rate
    return if event.attribute_values['occupation_rate'].to_f.eql?(presence_policy.occupation_rate)
    raise InvalidResourcesError.new(
      presence_policy,
      occupation_rate: ["Presence Policy occupation rate does not match event's occupation rate"]
    )
  end

  def attributes
    verify_presence_policy_existance
    effective_at = event.effective_at
    {
      effective_at: effective_at,
      employee_id: event.employee_id,
      order_of_start_day: 1,
      presence_policy_id: presence_policy.id,
      employee_event_id: event.id
    }
  end

  def verify_presence_policy_existance
    return unless presence_policy.nil?
    raise InvalidResourcesError.new(
      presence_policy,
      id: ['PresencePolicy does not exist']
    )
  end
end
