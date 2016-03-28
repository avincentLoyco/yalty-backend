require 'rails_helper'

RSpec.describe EmployeeTimeOffPolicy, type: :model do

  let(:etop) { create(:employee_time_off_policy) }
  let(:new_etop) do
    build(:employee_time_off_policy,
      employee_id: etop.employee_id,
      time_off_policy_id: etop.time_off_policy_id
    )
  end

  it { is_expected.to have_db_column(:employee_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:time_off_policy_id).of_type(:uuid) }
  it { is_expected.to validate_presence_of(:employee_id) }
  it { is_expected.to validate_presence_of(:time_off_policy_id) }
  it { is_expected.to have_db_index([:time_off_policy_id, :employee_id]).unique }

  it " validates uniqueness of compound key of time_off_policy_id and employee_id" do
    etop
    expect(new_etop).not_to be_valid
  end
end
