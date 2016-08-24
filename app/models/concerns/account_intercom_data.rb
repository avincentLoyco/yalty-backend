require 'active_support/concern'

module AccountIntercomData
  extend ActiveSupport::Concern

  def intercom_type
    :companies
  end

  def intercom_attributes
    %w( id created_at company_name subdomain last_time_off_vacation_date vacation_time_offs_count
        last_no_vacation_time_off_date last_manual_working_time_creation working_time_ratio
        last_vacation_time_off_date employee_ratio active_employee_count presence_policy_count
        active_presence_policy_count time_off_policy_count active_time_off_policy_count)
  end

  def intercom_data
    {
      company_id: id,
      name: company_name,
      remote_created_at: created_at,
      custom_attributes: [
        { subdomain: subdomain },
        intercom_policies_attributes,
        intercom_employee_attributes,
        intercom_time_offs_attributes,
        intercom_rwt_attributes
      ].inject(:merge)
    }
  end

  private

  def intercom_policies_attributes
    {
      presence_policy_count: PresencePolicy.for_account(id).count,
      active_presence_policy_count:
        ActiveAndInactiveJoinTableFinders.new(
          PresencePolicy,
          EmployeePresencePolicy,
          id
        ).active.count,
      time_off_policy_count: TimeOffPolicy.for_account(id).count,
      active_time_off_policy_count:
        ActiveAndInactiveJoinTableFinders.new(
          TimeOffPolicy,
          EmployeeTimeOffPolicy,
          id
        ).active.count
    }
  end

  def intercom_employee_attributes
    {
      active_employee_count: Employee.active_by_account(id).count,
      employee_ratio: Employee.active_employee_ratio_per_account(id)
    }
  end

  def intercom_time_offs_attributes
    {
      vacation_time_offs_count: TimeOff.vacations.for_account(id).count,
      no_vacation_time_offs_count: TimeOff.not_vacations.for_account(id).count,
      last_vacation_time_off_date:  TimeOff.vacations.for_account(id).last.try(:created_at),
      last_no_vacation_time_off_date: TimeOff.not_vacations.for_account(id).last.try(:created_at)
    }
  end

  def intercom_rwt_attributes
    {
      last_manual_working_time_creation:
        RegisteredWorkingTime.manually_created_by_account_ordered(id).last.try(:created_at),
      working_time_ratio: RegisteredWorkingTime.manually_created_ratio_per_account(id)
    }
  end
end
