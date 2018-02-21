require "active_support/concern"

module UserIntercomData
  extend ActiveSupport::Concern

  def intercom_type
    :users
  end

  def intercom_attributes
    %w(
      id created_at email role referral_token
      employee_id
      last_vacation_created_at last_other_time_off_created_at
      last_manual_working_time_created_at manual_working_time_ratio
      number_of_files total_amount_of_data
      number_of_events
    )
  end

  def intercom_data
    {
      user_id: id,
      email: email,
      signed_up_at: created_at,
      companies: [{
        company_id: account.id
      }],
      custom_attributes: [
        {
          referral_token: referrer.try(:token),
          role: role
        },
        intercom_employee_data
      ].inject(:merge)
    }
  end

  def intercom_employee_data
    if employee.present?
      {
        employee_id: employee.id,
        last_vacation_created_at:
          TimeOff.vacations.for_employee(employee.id).pluck(:created_at).last,
        last_other_time_off_created_at:
          TimeOff.not_vacations.for_employee(employee.id).pluck(:created_at).last,
        last_manual_working_time_created_at:
          RegisteredWorkingTime
            .manually_created_by_employee_ordered(employee.id)
            .pluck(:created_at)
            .last,
        manual_working_time_ratio:
          RegisteredWorkingTime.manually_created_ratio_per_employee(employee.id),
        number_of_files: employee.number_of_files,
        total_amount_of_data: employee.total_amount_of_data,
        number_of_events: employee.events.count
      }
    else
      {
        employee_id: nil,
        last_vacation_created_at: nil,
        last_other_time_off_created_at: nil,
        last_manual_working_time_created_at: nil,
        manual_working_time_ratio: nil,
        number_of_files: nil,
        total_amount_of_data: nil,
        number_of_events: nil
      }
    end
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
          contact.custom_attributes["beta_invitation_key"] == beta_invitation_key
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
