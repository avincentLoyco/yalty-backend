require 'rails_helper'

RSpec.describe AssignHolidayPolicy do
  include_context 'shared_context_geoloc_helper'

  before do
    Account.current = working_place.account
  end

  let(:working_place) { build :working_place, country: country, city: city, state: state_code }
  let(:account) { working_place.account }

  context 'with authorized country' do
    context 'when holiday policy is given' do
      subject { described_class.new(working_place, holiday_policy.id).call }
      context 'if account has given holiday policy' do
        let(:holiday_policy) { create :holiday_policy, account: account }
        before { subject }

        it { expect(working_place.holiday_policy_id).to eq(holiday_policy.id) }
      end
    end

    context "when holiday policy isn't given" do
      subject { described_class.new(working_place, nil).call }

      context 'holiday policy exists' do
        before { Account.current.holiday_policies = [holiday_policy] }

        let(:holiday_policy) do
          create :holiday_policy, account: account, country: country_code, region: state_code
        end

        before { subject }

        it { expect(working_place.holiday_policy_id).to eq(holiday_policy.id) }
      end

      context "holiday policy doesn't exist" do
        before { subject }

        it { expect(working_place.holiday_policy).not_to be(nil) }
        it { expect(working_place.holiday_policy.name).to eq(state_code) }
      end
    end
  end

  context 'with unauthorized country' do
    let(:city) { 'Warsaw' }
    let(:country) { 'Poland' }
    let(:country_code) { 'pl' }
    let(:state_code) { nil }

    context 'when holiday policy is given' do
      subject { described_class.new(working_place, holiday_policy.id).call }
      context 'if account has given holiday policy' do
        let(:holiday_policy) { create :holiday_policy, account: account }
        before { subject }

        it { expect(working_place.holiday_policy_id).to eq(holiday_policy.id) }
      end

      context "when holiday policy doesn't exist" do
        subject { described_class.new(working_place, 'asdf').call }

        it { expect { subject }.to raise_exception(ActiveRecord::RecordNotFound) }
      end
    end

    context "when holiday policy isn't given" do
      subject { described_class.new(working_place, nil).call }

      it { expect(working_place.holiday_policy).to be(nil) }
    end
  end
end
