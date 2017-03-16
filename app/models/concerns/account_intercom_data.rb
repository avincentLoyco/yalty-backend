require 'active_support/concern'

module AccountIntercomData
  extend ActiveSupport::Concern

  def intercom_type
    :companies
  end

  def intercom_attributes
    %w(
      id created_at company_name subdomain referred_by
      number_of_files total_amount_of_data employee_files_ratio
      vacation_count other_time_offs_count last_vacation_created_at last_other_time_off_created_at
      manual_working_time_ratio last_manual_working_time_created_at
      active_employee_count user_employee_ratio
      presence_policy_count active_presence_policy_count
      time_off_policy_count active_time_off_policy_count
    )
  end

  def intercom_data
    {
      company_id: id,
      name: company_name,
      remote_created_at: created_at,
      custom_attributes: [
        {
          subdomain: subdomain,
          referred_by: referred_by
        },
        intercom_files_attributes,
        intercom_policies_attributes,
        intercom_employee_attributes,
        intercom_time_offs_attributes,
        intercom_rwt_attributes
      ].inject(:merge)
    }
  end

  private

  def intercom_files_attributes
    {
      number_of_files: number_of_files,
      total_amount_of_data: total_amount_of_data,
      employee_files_ratio: employee_files_ratio
    }
  end

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
      user_employee_ratio: Employee.active_employee_ratio_per_account(id)
    }
  end

  def intercom_time_offs_attributes
    {
      vacation_count: TimeOff.vacations.for_account(id).count,
      other_time_offs_count: TimeOff.not_vacations.for_account(id).count,
      last_vacation_created_at:  TimeOff.vacations.for_account(id).pluck(:created_at).last,
      last_other_time_off_created_at: TimeOff.not_vacations.for_account(id).pluck(:created_at).last
    }
  end

  def intercom_rwt_attributes
    {
      last_manual_working_time_created_at:
        RegisteredWorkingTime.manually_created_by_account_ordered(id).pluck(:created_at).last,
      manual_working_time_ratio: RegisteredWorkingTime.manually_created_ratio_per_account(id)
    }
  end
end
