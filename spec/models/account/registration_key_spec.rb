require 'rails_helper'

RSpec.describe Account::RegistrationKey, type: :model do
  it { is_expected.to have_db_column(:token) }
  it { is_expected.to have_db_column(:account_id) }

  it { is_expected.to belong_to(:account) }

  context 'it generates token before validation' do
    let(:registration_key) { build(:registration_key) }

    it { expect { registration_key.valid? }.to change { registration_key.token }.from(nil) }
  end

  context 'scope' do
    let!(:key_without_account) { create_list(:registration_key, 2) }
    let!(:key_with_account) { create(:registration_key, :with_account) }
    let!(:key_with_account_zero) { create(:registration_key, account_id: "0") }

    it { expect(Account::RegistrationKey.count).to eql(4) }
    it { expect(Account::RegistrationKey.unused.count).to eql(2) }
  end
end
