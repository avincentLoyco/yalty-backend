namespace :work_events do
  WORK_EVENT_TYPES = %w(hired work_contract contract_end)
  task remove_after_2017: :environment do
    work_events            = Employee::Event.where(event_type: WORK_EVENT_TYPES)
    work_events_after_2017 =
      work_events.where('effective_at >= ?', Date.new(2018, 1, 1)).order(event_type: :desc)

    work_events_after_2017.each do |work_event|
      delete_working_places(work_event.employee, work_event.effective_at)
      delete_time_off_policies(work_event.employee, work_event.effective_at)
      delete_presence_policies(work_event.employee, work_event.effective_at)

      ActiveRecord::Base.transaction do
        remove_reset_resources(work_event, work_event.employee)
        work_event.destroy!
        create_missing_balances(work_event)
        ::Payments::UpdateSubscriptionQuantity.perform_now(work_event.employee.account)
        remove_employee(work_event.employee) unless work_event.employee.events.hired.exists?
      end
    end
  end

  def delete_working_places(employee, effective_at)
    employee_working_places =
      employee.employee_working_places.not_reset.assigned_since(effective_at)

    employee_working_places.each do |working_place|
      EmployeePolicy::WorkingPlace::Destroy.call(working_place)
    end
  end

  def delete_time_off_policies(employee, effective_at)
    employee_time_off_policies =
      employee.employee_time_off_policies.not_reset.assigned_since(effective_at)

    employee_time_off_policies.each do |employee_time_off_policy|
      EmployeePolicy::TimeOff::Destroy.call(employee_time_off_policy)
    end
  end

  def delete_presence_policies(employee, effective_at)
    employee_presence_policies =
      employee.employee_presence_policies.not_reset.assigned_since(effective_at)

    employee_presence_policies.each do |employee_presence_policy|
      EmployeePolicy::Presence::Destroy.call(employee_presence_policy)
    end
  end

  def remove_reset_resources(event, employee)
    return unless event.event_type.eql?('contract_end')
    ClearResetJoinTables.new(employee, event.effective_at - 1.day, nil, true).call
  end

  def create_missing_balances(event)
    return unless event.event_type.eql?('contract_end')
    policies_by_category(event, event.employee).map do |_category, policies|
      ManageEmployeeBalanceAdditions.new(policies.last).call
      next unless policies.last.time_off_policy.end_day.present?
      reset_date = event.effective_at + 1.day + Employee::Balance::RESET_OFFSET
      next unless first_balance_to_update(policies.first, reset_date).present?
      PrepareEmployeeBalancesToUpdate.new(@first_balance_to_update, update_all: true).call
      UpdateBalanceJob.perform_later(@first_balance_to_update, update_all: true)
    end
  end

  def policies_by_category(event, employee)
    employee
      .employee_time_off_policies
      .active_at(event.effective_at - 1.day)
      .order(:effective_at).group_by { |b| b[:time_off_category_id] }
  end

  def first_balance_to_update(policy, date)
    @first_balance_to_update ||=
      policy.employee_balances.where(validity_date: date).order(:effective_at).first
  end

  def remove_employee(employee)
    return if employee.events.hired.present?

    ActiveRecord::Base.transaction do
      employee.events.destroy_all
      employee.registered_working_times.destroy_all
      employee.destroy!
    end
  end
end
