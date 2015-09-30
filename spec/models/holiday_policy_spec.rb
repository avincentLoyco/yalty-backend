require 'rails_helper'

RSpec.describe HolidayPolicy, type: :model do
  it { is_expected.to have_db_column(:name) }
  it { is_expected.to have_db_column(:country) }
  it { is_expected.to have_db_column(:region) }
  it { is_expected.to have_many(:holidays) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:account_id) }

  let(:account) { FactoryGirl.create(:account) }

  context 'validations' do
    context 'country presence' do
      it 'should not be valid when region send but not country' do
        params = { name: 'test', region: 'pl', account: account }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy.valid?).to eq false
      end
    end

    context 'country inclusion' do
      it 'should be valid when country code not send' do
        params = { name: 'test', account: account }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy.valid?).to eq true
        expect { holiday_policy.save }.to change { HolidayPolicy.count }.from(0).to(1)
      end

      it 'should be valid when valid country code send capitalized' do
        params = { name: 'test', country: 'PL', account: account }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy.valid?).to eq true
        expect { holiday_policy.save }.to change { HolidayPolicy.count }.from(0).to(1)
      end

      it 'should be valid when valid country code send not downcased' do
        params = { name: 'test', country: 'pl', account: account }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy.valid?).to eq true
        expect { holiday_policy.save }.to change { HolidayPolicy.count }.from(0).to(1)
      end

      it 'should not be valid when invalid country code send' do
        params = { name: 'test', country: 'XYZ', account: account }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy.valid?).to eq false
      end
    end

    context 'region inclusion' do
      it 'should be valid when valid region code send capitalized' do
        params = { name: 'test', country: 'pl', region: 'ds', account: account }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy.valid?).to eq true
      end

      it 'should be valid when valid region code send downcased' do
        params = { name: 'test', country: 'pl', region: 'DS', account: account }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy.valid?).to eq true
      end

      it 'should not be valid when country code not send' do
        params = { name: 'test', region: 'DS', account: account  }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy.valid?).to eq false
      end

      it 'should not be valid when wrong country code send' do
        params = { name: 'test', country: 'xyz', region: 'DS', account: account }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy.valid?).to eq false
      end
    end
  end
end
