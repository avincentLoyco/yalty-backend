require 'rails_helper'

RSpec.describe WorkingPlaceTimeOffPolicy, type: :model do

  let(:wptop) { create(:working_place_time_off_policy) }

  it { is_expected.to have_db_column(:working_place_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:time_off_policy_id).of_type(:uuid) }
  it { is_expected.to validate_presence_of(:working_place_id) }
  it { is_expected.to validate_presence_of(:time_off_policy_id) }
  it { is_expected.to validate_presence_of(:effective_at) }
  it { is_expected.to have_db_index([:time_off_policy_id, :working_place_id]) }
  it '' do
    is_expected.to have_db_index([:working_place_id, :time_off_policy_id, :effective_at]).unique
  end
end
