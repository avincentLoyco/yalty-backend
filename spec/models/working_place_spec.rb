require 'rails_helper'

RSpec.describe WorkingPlace, type: :model do
  include_context 'shared_context_timecop_helper'

  it { is_expected.to have_db_column(:name) }

  it { is_expected.to have_db_column(:country) }
  it { is_expected.to have_db_column(:state) }
  it { is_expected.to have_db_column(:city) }
  it { is_expected.to have_db_column(:postalcode) }
  it { is_expected.to have_db_column(:street_number) }
  it { is_expected.to have_db_column(:street) }
  it { is_expected.to have_db_column(:additional_address) }
  it { is_expected.to have_db_column(:timezone) }

  it { is_expected.to have_many(:employees) }
  it { is_expected.to have_many(:employee_working_places) }
  it { is_expected.to respond_to(:employees) }

  it { is_expected.to have_db_column(:account_id).of_type(:uuid) }
  it { is_expected.to belong_to(:account).inverse_of(:working_places) }
  it { is_expected.to respond_to(:account) }

  it { is_expected.to validate_presence_of(:account) }
  it { is_expected.to validate_presence_of(:country) }
  it { is_expected.to validate_presence_of(:city) }

  it { is_expected.to validate_length_of(:country).is_at_most(60) }
  it { is_expected.to validate_length_of(:city).is_at_most(60) }
  it { is_expected.to validate_length_of(:state).is_at_most(60) }
  it { is_expected.to validate_length_of(:postalcode).is_at_most(12) }
  it { is_expected.to validate_length_of(:street).is_at_most(72) }
  it { is_expected.to validate_length_of(:street_number).is_at_most(10) }
  it { is_expected.to validate_length_of(:additional_address).is_at_most(60) }

  it { is_expected.to belong_to(:holiday_policy) }
end
