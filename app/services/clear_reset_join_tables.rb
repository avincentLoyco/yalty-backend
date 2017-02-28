class ClearResetJoinTables
  def initialize(employee, effective_at, time_off_category = nil)
    @employee = employee
    @contract_end_date = employee.first_upcoming_contract_end(effective_at).try(:effective_at)
    @reset_effective_at = @contract_end_date + 1.day if @contract_end_date.present?
    @time_off_category = time_off_category
  end

  def call
    return unless @contract_end_date.present?
    reset_presence_policy.destroy if remove_reset_presence_policy?
    reset_working_place.destroy if remove_reset_working_place?
    reset_time_off_policy.destroy if remove_reset_time_off_policy_in_category?
  end

  private

  def reset_presence_policy
    @employee
      .employee_presence_policies
      .with_reset
      .find_by(effective_at: @reset_effective_at)
  end

  def reset_working_place
    @employee
      .employee_working_places
      .with_reset
      .find_by(effective_at: @reset_effective_at)
  end

  def reset_time_off_policy
    @employee
      .employee_time_off_policies
      .with_reset
      .find_by(effective_at: @reset_effective_at, time_off_category: @time_off_category)
  end

  def remove_reset_presence_policy?
    policies_present =
      @employee
      .employee_presence_policies
      .not_reset
      .where('effective_at <= ?', @contract_end_date).empty?
    reset_presence_policy.present? && policies_present
  end

  def remove_reset_working_place?
    working_places_present =
      @employee
      .employee_working_places
      .not_reset
      .where('effective_at <= ?', @contract_end_date).empty?
    reset_working_place.present? && working_places_present
  end

  def remove_reset_time_off_policy_in_category?
    policies_present =
      @employee
      .employee_time_off_policies
      .not_reset
      .where('effective_at <= ?', @contract_end_date).empty?
    @time_off_category.present? && reset_time_off_policy.present? && policies_present
  end
end
