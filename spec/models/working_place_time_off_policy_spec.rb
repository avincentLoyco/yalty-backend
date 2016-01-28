require 'rails_helper'

RSpec.describe WorkingPlaceTimeOffPolicy, type: :model do

  let(:wptop) { create(:working_place_time_off_policy) }
  let(:new_wptop) do
    build(:working_place_time_off_policy,
      working_place_id: wptop.working_place_id,
      time_off_policy_id: wptop.time_off_policy_id
    )
  end

  it { is_expected.to have_db_column(:working_place_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:time_off_policy_id).of_type(:uuid) }
  it { is_expected.to validate_presence_of(:working_place_id) }
  it { is_expected.to validate_presence_of(:time_off_policy_id) }
  it { is_expected.to have_db_index([:time_off_policy_id, :working_place_id]).unique }

  it " validates uniqueness of compound key of time_off_policy_id and working_place_id" do
    wptop
    expect(new_wptop).not_to be_valid
  end
end
