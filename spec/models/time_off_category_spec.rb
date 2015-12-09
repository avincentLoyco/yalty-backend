require 'rails_helper'

RSpec.describe TimeOffCategory, type: :model do

  it { is_expected.to have_db_column(:account_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:name).of_type(:string) }
  it { is_expected.to have_db_column(:system).of_type(:boolean) }

  it { is_expected.to validate_presence_of(:account) }
  it { is_expected.to validate_presence_of(:name) }

  it { is_expected.to belong_to(:account) }

  it { expect(TimeOffCategory.new.system).to eq false }
end
