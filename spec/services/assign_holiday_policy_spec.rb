require 'rails_helper'

RSpec.describe AssignHolidayPolicy do
  include_context 'shared_context_geoloc_helper'

  before do
    Account.current = working_place.account
  end

  let!(:account) { working_place.account }
  let!(:holiday_policy) { create :holiday_policy, account: account, region: 'vd', country: 'ch' }

  let(:city) { 'Zurich' }
  let(:state_name) { 'Zurich' }
  let(:state_code) { 'ZH' }
  let(:state_param) { 'ZH' }
  let(:country) { 'Switzerland' }
  let(:country_code) { 'CH' }
  let(:country_param) { 'CH' }
  let(:timezone) { 'Europe/Zurich' }

  let(:working_place) { create :working_place, city: city, state: state_param, country: country }

  context 'with authorized country' do
    context 'when holiday policy is given' do
      subject { described_class.new(working_place, holiday_policy.id) }

      it { expect { subject.call }.to_not change { HolidayPolicy.count } }
      it { subject.call; expect(working_place.holiday_policy_id).to eq(holiday_policy.id) }
    end

    context "when holiday policy isn't given" do
      subject { described_class.new(working_place, nil) }

      context 'and a holiday policy matching working place coordinates exists' do
        let!(:holiday_policy) do
          create :holiday_policy, account: account, region: state_param, country: country_param
        end

        it { expect { subject.call }.to_not change { HolidayPolicy.count } }
        it { subject.call; expect(working_place.holiday_policy_id).to eq(holiday_policy.id) }
      end

      context "and a holiday policy matching working place coordinates doesn't exists" do
        it { expect { subject.call }.to change { HolidayPolicy.count }.by(1) }
        it { subject.call; expect(working_place.holiday_policy).not_to be(nil) }
        it { subject.call; expect(working_place.holiday_policy.name).to eq('Switzerland (ZH)') }
      end
    end
  end

  context 'with unauthorized country' do
    let(:city) { 'Rzeszow' }
    let(:state_name) { 'Podkarpackie Voivodeship' }
    let(:state_code) { 'Podkarpackie Voivodeship' }
    let(:state_param) { nil }
    let(:country) { 'Poland' }
    let(:country_code) { 'PL' }
    let(:timezone) { 'Europe/Warsaw' }

    context 'when holiday policy is given' do
      subject { described_class.new(working_place, holiday_policy.id) }

      context 'if account has given holiday policy' do
        let!(:holiday_policy) { create :holiday_policy, account: account }

        it { expect { subject.call }.to_not change { HolidayPolicy.count } }
        it { subject.call; expect(working_place.holiday_policy_id).to eq(holiday_policy.id) }
      end

      context "when holiday policy doesn't exist" do
        subject { described_class.new(working_place, 'NOT-AN-UUID') }

        it { expect { subject.call rescue nil }.to_not change { HolidayPolicy.count } }
        it { expect { subject.call }.to raise_exception(ActiveRecord::RecordNotFound) }
      end
    end

    context "when holiday policy isn't given" do
      subject { described_class.new(working_place, nil) }

      it { expect { subject.call }.to_not change { HolidayPolicy.count } }
      it { subject.call; expect(working_place.holiday_policy).to be(nil) }
    end
  end
end
