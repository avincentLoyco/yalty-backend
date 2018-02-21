RSpec.shared_context "shared_context_intercom_attributes" do
  let(:proper_account_intercom_attributes) do
    %w(
      id created_at company_name subdomain referred_by yalty_access
      number_of_files total_amount_of_data employee_files_ratio
      vacation_count other_time_offs_count last_vacation_created_at last_other_time_off_created_at
      manual_working_time_ratio last_manual_working_time_created_at
      active_employee_count user_employee_ratio employee_event_ratio
      presence_policy_count active_presence_policy_count
      time_off_policy_count active_time_off_policy_count
    )
  end

  let(:proper_account_data_keys) do
    %i(
      company_id name subdomain remote_created_at custom_attributes referred_by yalty_access
      number_of_files total_amount_of_data employee_files_ratio
      vacation_count other_time_offs_count last_vacation_created_at last_other_time_off_created_at
      manual_working_time_ratio last_manual_working_time_created_at
      active_employee_count user_employee_ratio employee_event_ratio
      presence_policy_count active_presence_policy_count
      time_off_policy_count active_time_off_policy_count
    )
  end

  let(:proper_user_intercom_attributes) do
    %w(
      id created_at email role referral_token
      employee_id
      last_vacation_created_at last_other_time_off_created_at
      last_manual_working_time_created_at manual_working_time_ratio
      number_of_files total_amount_of_data
      number_of_events
    )
  end

  let(:proper_user_data_keys) do
    %i(
      user_id email role referral_token signed_up_at custom_attributes companies
      employee_id
      last_vacation_created_at last_other_time_off_created_at
      last_manual_working_time_created_at manual_working_time_ratio
      number_of_files total_amount_of_data
      number_of_events
    )
  end
end
