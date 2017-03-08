class AssignResetJoinTable
  def initialize(resources_name, employee, time_off_category = nil, contract_end_date = nil)
    @resources_name = resources_name
    @employee = employee
    @account = employee.account
    @contract_end_date =
      contract_end_date || employee.first_upcoming_contract_end.try(:effective_at)
    @effective_at = @contract_end_date + 1.day if @contract_end_date.present?
    @time_off_category = time_off_category
  end

  def call
    return unless @contract_end_date.present? && create_reset_join_table?

    case @resources_name
    when 'presence_policies' then assing_presence_policy
    when 'working_places' then assing_working_place
    when 'time_off_policies' then assing_time_off_policies
    end
  end

  private

  def assing_presence_policy
    return if @employee.employee_presence_policies.with_reset.find_by(effective_at: @effective_at)
    EmployeePresencePolicy.create!(
      employee: @employee,
      presence_policy: @account.presence_policies.find_by(reset: true),
      effective_at: @effective_at
    )
  end

  def assing_working_place
    return if @employee.employee_working_places.with_reset.find_by(effective_at: @effective_at)
    EmployeeWorkingPlace.create!(
      employee: @employee,
      working_place: @account.working_places.find_by(reset: true),
      effective_at: @effective_at
    )
  end

  def assing_time_off_policies
    if @time_off_category.present?
      assign_single_reset_time_off_policy
    else
      assign_reset_time_off_policies_for_every_category
    end
  end

  def assign_single_reset_time_off_policy
    return if reset_policy_in_category?(@time_off_category)
    EmployeeTimeOffPolicy.create!(
      employee: @employee,
      time_off_policy:
        @account.time_off_policies.find_by(time_off_category: @time_off_category, reset: true),
      effective_at: @effective_at
    )
  end

  def assign_reset_time_off_policies_for_every_category
    @employee.time_off_categories.distinct.map do |category|
      next if reset_policy_in_category?(category)
      reset_policy = @account.time_off_policies.find_by(time_off_category: category, reset: true)
      EmployeeTimeOffPolicy.create!(
        employee: @employee,
        time_off_policy: reset_policy,
        effective_at: @effective_at
      )
    end
  end

  def reset_policy_in_category?(category)
    @employee.employee_time_off_policies
             .joins(:time_off_policy)
             .where(
               time_off_category: category,
               effective_at: @effective_at,
               time_off_policies: { reset: true }
             )
             .present?
  end

  def create_reset_join_table?
    resources_present =
      if @resources_name.eql?('time_off_policies')
        @employee.time_off_categories.distinct.present?
      else
        @employee.send(@resources_name)
                 .active_for_employee(@employee.id, @contract_end_date).present?
      end
    @time_off_category.present? || resources_present
  end
end
