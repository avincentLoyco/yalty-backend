require 'rails_helper'

RSpec.describe HolidayPolicy, type: :model do
  it { is_expected.to have_db_column(:country) }
  it { is_expected.to have_db_column(:region) }
  it { is_expected.to have_db_column(:account_id).of_type(:uuid) }
  it { is_expected.to validate_presence_of(:account_id) }

  let(:account) { create(:account) }

  context 'validations' do
    context 'country presence' do
      it 'should not be valid when region send but not country' do
        params = { region: 'pl', account: account }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy).to_not be_valid
        expect(holiday_policy.errors.messages[:country]).to include "can't be blank"
      end
    end

    context 'country inclusion' do
      it 'should not be valid when country code is empty' do
        params = { account: account }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy).to_not be_valid
        expect { holiday_policy.save }.to_not change { HolidayPolicy.count }
      end

      it 'should be valid when valid country code send capitalized' do
        params = { country: 'PL', account: account }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy).to be_valid
        expect { holiday_policy.save }.to change { HolidayPolicy.count }.from(0).to(1)
      end

      it 'should be valid when valid country code send downcased' do
        params = { country: 'pl', account: account }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy).to be_valid
        expect { holiday_policy.save }.to change { HolidayPolicy.count }.from(0).to(1)
      end

      it 'should not be valid when worong country code send' do
        params = { country: 'XYZ', account: account }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy).to_not be_valid
      end

      it 'should not be valid when country code not send' do
        params = { region: 'DS', account: account  }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy).to_not be_valid
      end
    end

    context 'region inclusion' do
      it 'should be valid when valid region code send capitalized' do
        params = { country: 'ch', region: 'ZH', account: account }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy).to be_valid
      end
      it 'should be valid when valid country and region code send capitalized' do
        params = { country: 'CH', region: 'ZH', account: account }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy).to be_valid
      end

      it 'should be valid when valid region code send downcased' do
        params = { country: 'ch', region: 'zh', account: account }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy).to be_valid
      end

      it 'should be valid when country need it regions' do
        params = { country: 'ch', region: 'zh', account: account }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy).to be_valid
        expect(holiday_policy.region).to eq 'zh'
      end

      it 'should not be valid when country require region and is wrong' do
        params = { country: 'ch', region: 'xx', account: account }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy).to_not be_valid
        expect(holiday_policy.region).to eq 'xx'
      end

      it 'should not be valid when country require region and is not set' do
        params = { country: 'CH', account: account  }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy).to_not be_valid
      end

      it 'should ignore region when country not need it' do
        params = { country: 'pl', region: 'ds', account: account }
        holiday_policy = HolidayPolicy.new(params)

        expect(holiday_policy).to be_valid
        expect(holiday_policy.region).to eq nil
      end
    end
  end
end
