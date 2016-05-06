require 'rails_helper'

RSpec.describe EmployeePresencePolicy, type: :model do
  let(:epp) { create(:employee_presence_policy) }

  it { is_expected.to have_db_column(:employee_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:presence_policy_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:effective_at).of_type(:date) }
  it { is_expected.to have_db_column(:start_day_order).of_type(:integer) }
  it { is_expected.to validate_presence_of(:employee_id) }
  it { is_expected.to validate_presence_of(:presence_policy_id) }
  it { is_expected.to validate_presence_of(:effective_at) }
  it { is_expected.to have_db_index([:presence_policy_id, :employee_id]) }
  it { is_expected.to have_db_index([:employee_id, :presence_policy_id, :effective_at]).unique }

end
