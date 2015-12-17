require 'rails_helper'

RSpec.describe TimeEntry, type: :model do
  it { is_expected.to have_db_column(:start_time).of_type(:time) }
  it { is_expected.to have_db_column(:end_time).of_type(:time) }
  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:presence_day_id).of_type(:uuid) }

  it { is_expected.to belong_to(:presence_day) }

  it { is_expected.to validate_presence_of(:start_time) }
  it { is_expected.to validate_presence_of(:end_time) }
  it { is_expected.to validate_presence_of(:presence_day_id) }


  context 'before validation calback' do
    subject { TimeEntry.new(start_time: Time.now) }

    it { expect { subject.valid? }.to change { subject.start_time } }
  end

  context 'custom validations' do
    context '#end_time_after_start_time' do
      subject { build(:time_entry, end_time: end_time)  }

      context 'when valid data' do
        let(:end_time) { Time.now + 4.hours }

        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.messages } }
      end

      context 'when invalid data' do
        let(:end_time) { Time.now - 4.hours }

        it { expect(subject.valid?).to eq false }
        it { expect { subject.valid? }.to change { subject.errors.messages[:end_time] } }
      end
    end

    context '#time_entry not reserved' do
      let(:time_entry) { build(:time_entry) }

      context 'when time_entrys do not overlap' do
        let(:new_time_entry) do
          TimeEntry.new(
            presence_day: time_entry.presence_day,
            start_time: time_entry.end_time + 1.hour,
            end_time: time_entry.end_time + 3.hours )
        end
        before { time_entry.save! }

        it { expect(new_time_entry.valid?).to eq true }
        it { expect { new_time_entry.valid? }.to_not change { new_time_entry.errors.messages.count } }
      end

      context 'when time_entrys overlap' do
        let(:duplicate_time_entry) { time_entry.dup }
        before { time_entry.save! }

        it { expect(duplicate_time_entry.valid?).to eq false }
        it { expect { duplicate_time_entry.valid? }
          .to change { duplicate_time_entry.errors.messages.count }.by(1) }
      end
    end
  end
end
