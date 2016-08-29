RSpec.shared_context 'shared_context_intercom_attributes' do
  let(:proper_account_intercom_attributes) do
    %w(
      id created_at company_name subdomain
      vacation_count other_time_offs_count last_vacation_created_at last_other_time_off_created_at
      manual_working_time_ratio last_manual_working_time_created_at
      active_employee_count user_employee_ratio
      presence_policy_count active_presence_policy_count
      time_off_policy_count active_time_off_policy_count
    )
  end

  let(:proper_account_data_keys) do
    %i(
      company_id name subdomain remote_created_at custom_attributes
      vacation_count other_time_offs_count last_vacation_created_at last_other_time_off_created_at
      manual_working_time_ratio last_manual_working_time_created_at
      active_employee_count user_employee_ratio
      presence_policy_count active_presence_policy_count
      time_off_policy_count active_time_off_policy_count
    )
  end

  let(:proper_user_intercom_attributes) do
    %w(
      id created_at email account_manager
      employee_id
      last_vacation_created_at last_other_time_off_created_at
      last_manual_working_time_created_at manual_working_time_ratio
    )
  end

  let(:proper_user_data_keys) do
    %i(
      user_id email account_manager signed_up_at custom_attributes companies
      employee_id
      last_vacation_created_at last_other_time_off_created_at
      last_manual_working_time_created_at manual_working_time_ratio
    )
  end
end
