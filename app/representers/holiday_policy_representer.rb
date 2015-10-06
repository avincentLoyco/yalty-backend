class HolidayPolicyRepresenter
  attr_reader :holiday_policy

  def initialize(holiday_policy)
    @holiday_policy = holiday_policy
  end

  def basic
    {
      id:   holiday_policy.id,
      type: 'holiday_policy',
    }
  end
end
