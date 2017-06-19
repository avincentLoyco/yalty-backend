class DeleteEvent
  attr_reader :event, :employee

  def initialize(event)
    @event = event
    @employee = event.employee
  end

  def call
    return event.destroy! unless event.event_type.in?(%w(hired contract_end))
    ActiveRecord::Base.transaction do
      remove_reset_resources
      event.destroy!
      create_missing_balances
      ::Payments::UpdateSubscriptionQuantity.perform_now(employee.account)
      RemoveEmployee.new(employee).call unless employee.events.hired.exists?
    end
  end

  def remove_reset_resources
    return unless event.event_type.eql?('contract_end')
    ClearResetJoinTables.new(employee, event.effective_at - 1.day, nil, true).call
  end

  def create_missing_balances
    return unless event.event_type.eql?('contract_end')
    policies_by_category.map do |_category, policies|
      ManageEmployeeBalanceAdditions.new(policies.last).call
      next unless policies.last.time_off_policy.end_day.present?
      reset_date = event.effective_at + 1.day + Employee::Balance::RESET_OFFSET
      next unless first_balance_to_update(policies.first, reset_date).present?
      PrepareEmployeeBalancesToUpdate.new(@first_balance_to_update, update_all: true).call
      UpdateBalanceJob.perform_later(@first_balance_to_update, update_all: true)
    end
  end

  def policies_by_category
    employee
      .employee_time_off_policies
      .active_at(event.effective_at - 1.day)
      .order(:effective_at).group_by { |b| b[:time_off_category_id] }
  end

  def first_balance_to_update(policy, date)
    @first_balance_to_update ||=
      policy.employee_balances.where(validity_date: date).order(:effective_at).first
  end
end
