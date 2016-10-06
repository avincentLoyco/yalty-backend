require 'rails_helper'

RSpec.describe Referrer, type: :model do
  describe 'validations' do
    subject { build(:referrer, :with_token) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email) }
    it { is_expected.to validate_uniqueness_of(:token) }
    it { is_expected.to have_many(:users).with_primary_key(:email).with_foreign_key(:email) }
    it do
      is_expected
        .to have_many(:referred_accounts).with_primary_key(:token).with_foreign_key(:referred_by)
    end

    context 'token' do
      let(:referrer_one) { create(:referrer, token: nil) }
      let(:referrer_two) { create(:referrer, token: '1234') }
      subject(:update_referrer_two) { referrer_two.update!(email: 'test@example.com') }

      it { expect(referrer_one.token).to_not be(nil) }
      it { expect { update_referrer_two }.to_not change(referrer_two, :token) }

      context 'all tokens taken' do
        let(:tokens) do
          tokens = []
          while tokens.size != 256
            token = SecureRandom.hex(1)
            tokens.push(token) unless tokens.include?(token)
          end
          tokens
        end

        before do
          stub_const('Referrer::TOKEN_LENGTH', 1)
          tokens.each { |token| create(:referrer, token: token) }
        end

        it do
          expect { create(:referrer) }
            .to raise_error(Referrer::InvalidToken, 'Reached maximum number of regenerations.')
        end
      end
    end
  end

  describe 'asscociations' do
    let(:user_email) { 'test@example.com' }
    let!(:referrer) { create(:referrer, email: user_email) }
    let(:accounts) { create_list(:account, 2) }
    let(:user_a) { create(:account_user, email: user_email, account: accounts.first) }
    let(:user_b) { create(:account_user, email: user_email, account: accounts.last) }
    let!(:referred_accounts) { create_list(:account, 2, referred_by: referrer.token) }
    let(:resources) { [user_a, user_b] + referred_accounts }

    it { expect(referrer.users).to include(user_a, user_b) }
    it { expect(referrer.referred_accounts.ids).to match_array(referred_accounts.map(&:id)) }
    it { resources.each { |resource| expect(resource.referrer.id).to eq(referrer.id) } }
  end
end
