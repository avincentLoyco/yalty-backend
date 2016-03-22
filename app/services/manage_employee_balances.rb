class ManageEmployeeBalances
  attr_reader :previous_policy, :related, :current_policy, :resource_policy

  def initialize(resource_policy)
    @resource_policy = resource_policy
    @current_policy = resource_policy.time_off_policy
    @related = find_related
    @previous_policy = related.previous_time_off_policy(current_policy.time_off_category_id)
  end

  def call
    return if current_policy.start_date > Time.zone.today
    create_or_update_previous_policy_balance
  end

  private

  def create_or_update_previous_policy_balance
    if previous_policy && previous_policy.start_date == current_policy.start_date
      # update balance
    else
      # create new balance
    end
  end

  def find_related
    return resource_policy.employee if resource_policy.is_a?(EmployeeTimeOffPolicy)
    resource_policy.working_place
  end
end
