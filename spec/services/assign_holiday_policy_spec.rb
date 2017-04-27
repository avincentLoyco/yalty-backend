require 'rails_helper'

RSpec.describe AssignHolidayPolicy do
  include_context 'shared_context_geoloc_helper'

  before do
    Account.current = working_place.account
  end

  let!(:account) { working_place.account }
  let!(:holiday_policy) { create :holiday_policy, account: account, region: 'vd', country: 'ch' }

  let(:state_name) { 'Zurich' }
  let(:state_code) { 'ZH' }
  let(:state_param) { 'ZH' }
  let(:country) { 'Switzerland' }
  let(:country_code) { 'CH' }
  let(:country_param) { 'CH' }
  let(:timezone) { 'Europe/Zurich' }

  let(:working_place) { create :working_place, city: city, state_code: state_param, country_code: country_code }

  context 'with authorized country' do
    subject { described_class.new(working_place) }

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
    end
  end

  context 'with unauthorized country' do
    let(:state_name) { 'Podkarpackie Voivodeship' }
    let(:state_code) { 'Podkarpackie Voivodeship' }
    let(:state_param) { nil }
    let(:country) { 'Poland' }
    let(:country_code) { 'PL' }
    let(:timezone) { 'Europe/Warsaw' }

    subject { described_class.new(working_place) }

    it { expect { subject.call }.to_not change { HolidayPolicy.count } }
    it { subject.call; expect(working_place.holiday_policy).to be(nil) }
  end

  context 'without address' do
    let(:state_name) { nil }
    let(:state_code) { nil }
    let(:state_param) { nil }
    let(:country) { nil }
    let(:country_code) { nil }
    let(:timezone) { nil }

    subject { described_class.new(working_place) }

    it { expect { subject.call }.to_not change { HolidayPolicy.count } }
    it { subject.call; expect(working_place.holiday_policy).to be(nil) }
  end

  context 'when removing the assigned policy' do
    let(:state_name) { nil }
    let(:state_code) { nil }
    let(:state_param) { nil }
    let(:country) { nil }
    let(:country_code) { nil }
    let(:timezone) { nil }

    subject { described_class.new(working_place) }

    before do
      working_place.update!(holiday_policy_id: holiday_policy.id)
    end

    it { expect { subject.call }.to_not change { HolidayPolicy.count } }
    it { expect { subject.call }.to change { working_place.holiday_policy } }
    it { subject.call; expect(working_place.holiday_policy).to be(nil) }
  end
end
