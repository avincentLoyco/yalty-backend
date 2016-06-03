require 'rails_helper'

RSpec.describe PresencePolicy, type: :model do
  it { is_expected.to have_db_column(:name) }
  it { is_expected.to have_db_column(:account_id).of_type(:uuid) }
  it { is_expected.to have_many(:employees) }
  it { is_expected.to belong_to(:account) }
  it { is_expected.to validate_presence_of(:account_id) }
  it { is_expected.to validate_presence_of(:name) }
end
