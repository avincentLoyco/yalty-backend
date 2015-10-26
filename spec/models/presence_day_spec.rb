require 'rails_helper'

RSpec.describe PresenceDay, type: :model do
  it { is_expected.to have_db_column(:hours) }
  it { is_expected.to have_db_column(:order) }
  it { is_expected.to belong_to(:presence_policy) }
  it { is_expected.to validate_presence_of(:order) }
  it { is_expected.to validate_presence_of(:presence_policy_id) }

  context 'uniqueness validations' do
    let(:presence_day) { create(:presence_day) }
    let(:duplicate_presence_day) { PresenceDay.new(presence_day.attributes) }

    it 'should validate uniquness of order' do
      expect { duplicate_presence_day.valid? }
        .to change { duplicate_presence_day.errors.messages[:order] }
    end

    it 'should respond with already been taken error' do
      duplicate_presence_day.save

      expect(duplicate_presence_day.errors[:order]).to include 'has already been taken'
    end
  end
end
