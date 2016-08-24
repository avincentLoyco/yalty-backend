RSpec.shared_context 'shared_context_intercom_attributes' do
  let(:proper_account_intercom_attributes) do
    %w( id created_at company_name subdomain last_time_off_vacation_date vacation_time_offs_count
        last_no_vacation_time_off_date last_manual_working_time_creation working_time_ratio
        last_vacation_time_off_date employee_ratio active_employee_count presence_policy_count
        active_presence_policy_count time_off_policy_count active_time_off_policy_count)
  end

  let(:proper_account_data_keys) do
    %i( company_id name remote_created_at custom_attributes subdomain presence_policy_count
        active_presence_policy_count time_off_policy_count active_time_off_policy_count
        active_employee_count employee_ratio vacation_time_offs_count no_vacation_time_offs_count
        last_vacation_time_off_date last_no_vacation_time_off_date last_manual_working_time_creation
        working_time_ratio)
  end

  let(:proper_user_intercom_attributes) do
    %w( id created_at email account_manager employee last_time_off_vacation_date
        last_no_vacation_time_off_date last_manual_working_time_creation working_time_ratio
        last_vacation_time_off_date)
  end
  let(:proper_user_data_keys) do
    %i( user_id email signed_up_at custom_attributes companies account_manager employee_id
        last_vacation_time_off_date last_no_vacation_time_off_date last_manual_working_time_creation
        working_time_ratio)
  end
end
