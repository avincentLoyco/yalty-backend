require 'rails_helper'

RSpec.describe HolidayPolicy, type: :model do
  it { is_expected.to have_db_column(:name) }
  it { is_expected.to have_db_column(:country) }
  it { is_expected.to have_db_column(:region) }
  it { is_expected.to validate_presence_of(:name) }
end
