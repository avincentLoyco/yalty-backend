require 'rails_helper'

RSpec.describe WorkingPlace, type: :model do
  it { is_expected.to have_db_column(:name) }

  it { is_expected.to have_many(:employees) }
  it { is_expected.to respond_to(:employees) }

  it { is_expected.to have_db_column(:account_id).of_type(:uuid) }
  it { is_expected.to belong_to(:account).inverse_of(:working_places) }
  it { is_expected.to respond_to(:account) }
  it { is_expected.to validate_presence_of(:account) }
  it { is_expected.to belong_to(:holiday_policy) }
  it { is_expected.to belong_to(:presence_policy) }
end
