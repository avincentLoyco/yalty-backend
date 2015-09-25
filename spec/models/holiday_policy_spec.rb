require 'rails_helper'

RSpec.describe HolidayPolicy, type: :model do
  it { is_expected.to have_db_column(:name) }
  it { is_expected.to have_db_column(:country) }
  it { is_expected.to have_db_column(:region) }
  it { is_expected.to validate_presence_of(:name) }

  context 'country inclusion' do
    it 'should be valid when country code not send' do
      params = { name: 'test' }
      holiday_policy = HolidayPolicy.new(params)

      expect(holiday_policy.valid?).to eq true
      expect { holiday_policy.save }.to change { HolidayPolicy.count }.from(0).to(1)
    end

    it 'should be valid when valid country code send' do
      params = { name: 'test', country: 'PL' }
      holiday_policy = HolidayPolicy.new(params)

      expect(holiday_policy.valid?).to eq true
      expect { holiday_policy.save }.to change { HolidayPolicy.count }.from(0).to(1)
    end

    it 'should be valid when valid country code send' do
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
end
