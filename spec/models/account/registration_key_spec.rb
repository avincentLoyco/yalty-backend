require 'rails_helper'

RSpec.describe Account::RegistrationKey, type: :model do
  it { is_expected.to have_db_column(:token) }
  it { is_expected.to have_db_column(:account_id) }

  it { is_expected.to belong_to(:account) }

  context 'it generates token before validation' do
    let(:registration_key) { build(:registration_key) }

    it { expect { registration_key.valid? }.to change { registration_key.token }.from(nil) }
  end
end
