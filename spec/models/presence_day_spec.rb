require 'rails_helper'

RSpec.describe PresenceDay, type: :model do
  it { is_expected.to have_db_column(:minutes).of_type(:integer) }
  it { is_expected.to have_db_column(:order).of_type(:integer) }
  it { is_expected.to belong_to(:presence_policy) }
  it { is_expected.to have_many(:time_entries) }
  it { is_expected.to validate_presence_of(:order) }
  it { is_expected.to validate_presence_of(:presence_policy_id) }
  it { is_expected.to validate_numericality_of(:minutes).is_less_than_or_equal_to(1440) }

  context 'uniqueness validations' do
    let(:presence_day) { create(:presence_day) }

    context 'for records with the same presence policy' do
      let(:duplicate_presence_day) { PresenceDay.new(presence_day.attributes) }

      it { expect { duplicate_presence_day.valid? }
          .to change { duplicate_presence_day.errors.messages[:order] } }

      context 'error messages' do
        before { duplicate_presence_day.save }

        it { expect(duplicate_presence_day.errors[:order]).to include 'has already been taken' }
      end
    end

    context 'for records with different presence policy' do
      let(:presence_policy) { create(:presence_policy) }
      let(:second_presence_day) do
        PresenceDay.new(order: presence_day.order, presence_policy: presence_policy)
      end

      it { expect { second_presence_day.valid? }
        .to_not change { second_presence_day.errors.messages[:order] } }

      context 'error messages' do
        before { second_presence_day.save }

        it { expect(expect(second_presence_day.errors[:order]).to eq([])) }
      end
    end
  end
end
