require 'active_support/concern'

module UserIntercomData
  extend ActiveSupport::Concern

  def intercom_type
    :users
  end

  def intercom_attributes
    %w( id created_at email account_manager employee last_time_off_vacation_date
        last_no_vacation_time_off_date last_manual_working_time_creation working_time_ratio
        last_vacation_time_off_date)
  end

  def intercom_data
    {
      user_id: id,
      email: email,
      signed_up_at: created_at,
      custom_attributes: {
        account_manager: account_manager,
        employee_id: intercom_employee_data[:employee_id],
        last_vacation_time_off_date: intercom_employee_data[:last_vacation_time_off_date],
        last_no_vacation_time_off_date: intercom_employee_data[:last_no_vacation_time_off_date],
        last_manual_working_time_creation:
          intercom_employee_data[:last_manual_working_time_creation],
        working_time_ratio: intercom_employee_data[:working_time_ratio]
      },
      companies: [{
        company_id: account.id
      }]
    }
  end

  def intercom_employee_data
    return {} unless employee.present?
    @intercom_employee_data ||= {
      employee_id: employee.id,
      last_vacation_time_off_date: TimeOff.vacations.for_employee(employee.id).last,
      last_no_vacation_time_off_date: TimeOff.not_vacations.for_employee(employee.id).last,
      last_manual_working_time_creation:
        RegisteredWorkingTime.manually_created_by_employee_ordered(employee.id).last,
      working_time_ratio: RegisteredWorkingTime.manually_created_ratio_per_employee(employee.id)
    }
  end

  def intercom_user
    return unless intercom_client.present?
    @intercom_user ||= intercom_client.users.find(user_id: id)
  end

  def intercom_leads
    return unless intercom_client.present?

    @intercom_leads ||= begin
      beta_invitation_key = account.registration_key.try(:token)

      if beta_invitation_key.present?
        lead = intercom_client.contacts.all.find do |contact|
          contact.custom_attributes['beta_invitation_key'] == beta_invitation_key
        end
      end
      leads = intercom_client.contacts.find_all(email: email) if lead.nil?

      leads || [lead]
    end
  end

  def convert_intercom_leads
    return unless intercom_user.present?

    intercom_leads.each do |lead|
      intercom_client.contacts.convert(lead, intercom_user)
    end
  rescue Intercom::IntercomError
    Rails.logger.error "An error occur on when '#{email}' lead is converted to user '#{id}'"
  end

  def intercom_client
    @intercom_client ||= IntercomService.new.client
  end
end
