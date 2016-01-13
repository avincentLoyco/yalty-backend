require 'rails_helper'

RSpec.describe WorkingPlaceTimeOffPolicy, type: :model do

  it { is_expected.to have_db_column(:working_place_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:time_off_policy_id).of_type(:uuid) }
  it { is_expected.to validate_presence_of(:working_place_id) }
  it { is_expected.to validate_presence_of(:time_off_policy_id) }
end
