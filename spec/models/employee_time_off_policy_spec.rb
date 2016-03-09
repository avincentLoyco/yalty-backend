require 'rails_helper'

RSpec.describe EmployeeTimeOffPolicy, type: :model do

  let(:etop) { create(:employee_time_off_policy) }

  it { is_expected.to have_db_column(:employee_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:time_off_policy_id).of_type(:uuid) }
  it { is_expected.to validate_presence_of(:employee_id) }
  it { is_expected.to validate_presence_of(:time_off_policy_id) }
    it { is_expected.to validate_presence_of(:effective_at) }
  it { is_expected.to have_db_index([:time_off_policy_id, :employee_id]) }
  it '' do
    is_expected.to have_db_index([:employee_id, :time_off_policy_id, :effective_at]).unique
  end
end
