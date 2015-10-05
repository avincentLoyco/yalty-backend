require 'rails_helper'

RSpec.describe Holiday, type: :model do
  it { is_expected.to have_db_column(:name) }
  it { is_expected.to have_db_column(:date) }
  it { is_expected.to belong_to(:holiday_policy) }
  it { is_expected.to validate_presence_of(:holiday_policy_id) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:date) }
end
