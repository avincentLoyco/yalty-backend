class ClearResetJoinTables
  def self.call(employee, effective_at, time_off_category = nil, contract_end_destroy = false)
    new(employee, effective_at, time_off_category, contract_end_destroy).call
  end

  def initialize(employee, effective_at, time_off_category = nil, contract_end_destroy = false)
    @employee = employee
    @contract_end_date = employee.first_upcoming_contract_end(effective_at).try(:effective_at)
    @reset_effective_at = @contract_end_date + 1.day if @contract_end_date.present?
    @time_off_category = time_off_category
    @contract_end_destroy = contract_end_destroy
    @last_hired = find_employee_hired_date(effective_at)
  end

  def call
    return unless @contract_end_date.present?
    reset_presence_policy.destroy! if remove_reset_presence_policy?
    reset_working_place.destroy! if remove_reset_working_place?
    destroy_reset_policies if remove_reset_time_off_policy_in_category?
    reset_balances.map(&:destroy!) if @contract_end_destroy
  end

  private

  def find_employee_hired_date(effective_at)
    return @employee.hired_date_for(effective_at) if effective_at.present?
    @employee.contract_periods.first.first
  end

  def destroy_reset_policies
    reset_time_off_policies.map do |policy|
      reset_time_off_policies.first.policy_assignation_balance.try(:destroy!)
      policy.destroy!
    end
  end

  def reset_presence_policy
    @employee.employee_presence_policies.with_reset.find_by(effective_at: @reset_effective_at)
  end

  def reset_working_place
    @employee.employee_working_places.with_reset.find_by(effective_at: @reset_effective_at)
  end

  def reset_time_off_policies
    reset_policies =
      @employee.employee_time_off_policies.with_reset.where(effective_at: @reset_effective_at)

    return reset_policies unless @time_off_category.present?
    reset_policies.where(time_off_category: @time_off_category)
  end

  def reset_balances
    @employee
      .employee_balances
      .where(balance_type: "reset")
      .where("effective_at::date = ?", @reset_effective_at)
  end

  def remove_reset_presence_policy?
    policies_present =
      @employee
      .employee_presence_policies
      .not_reset
      .where("effective_at BETWEEN ? AND ?", @last_hired, @contract_end_date).empty?
    reset_presence_policy.present? && (policies_present || @contract_end_destroy)
  end

  def remove_reset_working_place?
    working_places_present =
      @employee
      .employee_working_places
      .not_reset
      .where("effective_at BETWEEN ? AND ?", @last_hired, @contract_end_date).empty?
    reset_working_place.present? && (working_places_present || @contract_end_destroy)
  end

  def remove_reset_time_off_policy_in_category?
    reset_time_off_policies.present? && (time_off_policies.empty? || @contract_end_destroy)
  end

  def time_off_policies
    time_off_policies =
      @employee
      .employee_time_off_policies
      .not_reset
      .where("effective_at BETWEEN ? AND ?", @last_hired, @contract_end_date)

    return time_off_policies if @time_off_category.nil?
    time_off_policies.where(time_off_category: @time_off_category)
  end
end
