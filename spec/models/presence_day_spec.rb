require 'rails_helper'

RSpec.describe PresenceDay, type: :model do
  it { is_expected.to have_db_column(:minutes).of_type(:integer) }
  it { is_expected.to have_db_column(:order).of_type(:integer) }
  it { is_expected.to belong_to(:presence_policy) }
  it { is_expected.to have_many(:time_entries) }
  it { is_expected.to validate_presence_of(:order) }
  it { is_expected.to validate_presence_of(:presence_policy_id) }

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

  context 'helper methods' do
    let(:day) { create(:presence_day, order: sub_order) }

    context 'presence day time entries' do
      let(:sub_order) { '2' }
      let!(:first_entry) do
        create(:time_entry, presence_day: day, start_time: '10:00', end_time: '12:00')
      end
      let!(:second_entry) do
        create(:time_entry, presence_day: day, start_time: '12:00', end_time: '14:00')
      end

      context '#update minutes!' do
        subject { day.update_minutes! }

        it { expect { subject }.to change { day.reload.minutes }.by(240) }
      end

      context '#last day entry' do
        subject { day.last_day_entry }

        it { expect(subject).to eq(second_entry) }
      end

      context '#first day entry' do
        subject { day.first_day_entry }

        it { expect(subject).to eq(first_entry) }
      end
    end

    context 'presence day policy days' do
      let!(:first_day) do
        create(:presence_day, presence_policy: day.presence_policy, order: first_order)
      end
      let!(:second_day) do
        create(:presence_day, presence_policy: day.presence_policy, order: second_order)
      end

      context '#next day' do
        subject { day.next_day }
        let(:first_order) { 1 }

        context 'when presence day is last in policy' do
          let(:sub_order) { 3 }
          let(:second_order) { 2 }

          it { expect(subject).to eq(first_day) }
        end

        context 'when presence day is not last in policy' do
          let(:sub_order) { 2 }
          let(:second_order) { 3 }

          it { expect(subject).to eq(second_day) }
        end
      end

      context '#previous day' do
        subject { day.previous_day }
        let(:second_order) { 3 }

        context 'when presence day is first in policy' do
          let(:sub_order) { 1 }
          let(:first_order) { 2 }

          it { expect(subject).to eq(second_day) }
        end

        context 'when presence day is not first in policy' do
          let(:sub_order) { 2 }
          let(:first_order) { 1 }

          it { expect(subject).to eq(first_day) }
        end
      end
    end
  end
end
