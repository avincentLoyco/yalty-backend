require 'rails_helper'

RSpec.describe Employee, type: :model do
  it { is_expected.to have_db_column(:account_id) }
  it { is_expected.to belong_to(:account).inverse_of(:employees) }
  it { is_expected.to respond_to(:account) }
  it { is_expected.to validate_presence_of(:account) }

  it { is_expected.to belong_to(:working_place) }

  it { is_expected.to have_many(:employee_attribute_versions).inverse_of(:employee) }

  it { is_expected.to have_many(:employee_attributes).inverse_of(:employee) }

  it { is_expected.to have_many(:events).inverse_of(:employee) }
end
