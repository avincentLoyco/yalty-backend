require 'rails_helper'

RSpec.describe HolidayPolicy, type: :model do
  it { is_expected.to have_db_column(:name) }
  it { is_expected.to have_db_column(:country) }
  it { is_expected.to have_db_column(:region) }
  it { is_expected.to have_many(:holidays) }
  it { is_expected.to validate_presence_of(:name) }

  context 'validations' do
    context 'country presence' do
      it 'should not be valid when region send but not country' do
      params = { name: 'test', region: 'pl' }
      holiday_policy = HolidayPolicy.new(params)

      expect(holiday_policy.valid?).to eq false
      end
    end

    context 'country inclusion' do
      it 'should be valid when country code not send' do
        params = { name: 'test' }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy.valid?).to eq true
        expect { holiday_policy.save }.to change { HolidayPolicy.count }.from(0).to(1)
      end

      it 'should be valid when valid country code send capitalized' do
        params = { name: 'test', country: 'PL' }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy.valid?).to eq true
        expect { holiday_policy.save }.to change { HolidayPolicy.count }.from(0).to(1)
      end

      it 'should be valid when valid country code send not downcased' do
        params = { name: 'test', country: 'pl' }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy.valid?).to eq true
        expect { holiday_policy.save }.to change { HolidayPolicy.count }.from(0).to(1)
      end

      it 'should not be valid when invalid country code send' do
        params = { name: 'test', country: 'XYZ' }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy.valid?).to eq false
      end
    end

    context 'region inclusion' do
      it 'should be valid when valid region code send capitalized' do
        params = { name: 'test', country: 'pl', region: 'ds' }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy.valid?).to eq true
      end

      it 'should be valid when valid region code send downcased' do
        params = { name: 'test', country: 'pl', region: 'DS' }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy.valid?).to eq true
      end

      it 'should not be valid when country code not send' do
        params = { name: 'test', region: 'DS' }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy.valid?).to eq false
      end

      it 'should not be valid when wrong country code send' do
        params = { name: 'test', country: 'xyz', region: 'DS' }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy.valid?).to eq false
      end
    end
  end
end
