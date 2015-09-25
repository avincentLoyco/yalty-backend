require 'rails_helper'

RSpec.describe WorkingPlace, type: :model do
  it { is_expected.to have_db_column(:name) }
  it { is_expected.to have_many(:employees) }
  it { is_expected.to respond_to(:employees) }
  it { is_expected.to belong_to(:account) }
  it { is_expected.to respond_to(:account) }
end
