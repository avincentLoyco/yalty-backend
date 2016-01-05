require 'rails_helper'

RSpec.describe TimeEntry, type: :model do
  it { is_expected.to have_db_column(:start_time).of_type(:string) }
  it { is_expected.to have_db_column(:end_time).of_type(:string) }
  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:presence_day_id).of_type(:uuid) }

  it { is_expected.to belong_to(:presence_day) }

  it { is_expected.to validate_presence_of(:start_time) }
  it { is_expected.to validate_presence_of(:end_time) }
  it { is_expected.to validate_presence_of(:presence_day) }

  context 'before validation calback' do
    subject { TimeEntry.new(start_time: '14:00', end_time: '16:00') }

    it { expect { subject.valid? }.to change { subject.start_time }.to('14:00:00') }
    it { expect { subject.valid? }.to change { subject.end_time }.to('16:00:00') }
  end

  context 'custom validations' do
    context '#start_time_format' do
      subject { TimeEntry.new(start_time: 'abc') }

      it { expect { subject.valid? }.to change { subject.errors.messages[:start_time] } }
      it 'should contain error message' do
        subject.valid?

        expect(subject.errors.messages[:start_time])
          .to include('Invalid format: Time format required.')
      end
    end

    context '#end_time_format' do
      subject { TimeEntry.new(end_time: 'abc') }

      it { expect { subject.valid? }.to change { subject.errors.messages[:end_time] } }
      it 'should contain error message' do
        subject.valid?

        expect(subject.errors.messages[:end_time])
          .to include('Invalid format: Time format required.')
      end
    end

    context '#time_order' do
      subject { build(:time_entry, start_time: '14:00', end_time: end_time) }

      context 'when valid data' do
        context 'end time different than 00:00:00' do
          let(:end_time) { '16:00' }

          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.to_not change { subject.errors.messages } }
        end

        context 'end time eq 00:00:00' do
          let(:end_time) { '00:00' }

          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.to_not change { subject.errors.messages } }
        end
      end

      context 'when invalid data' do
        let(:end_time) { '12:00' }

        it { expect(subject.valid?).to eq false }
        it { expect { subject.valid? }.to change { subject.errors.messages[:end_time] } }
      end
    end

    context '#time_entry_not_reserved' do
      let(:time_entry) { build(:time_entry) }

      context 'when time_entrys do not overlap' do
        let(:new_time_entry) do
          TimeEntry.new(
            presence_day: time_entry.presence_day,
            start_time: '18:00',
            end_time: '20:00')
        end
        before { time_entry.save! }

        it { expect(new_time_entry.valid?).to eq true }
        it { expect { new_time_entry.valid? }
          .to_not change { new_time_entry.errors.messages.count } }
      end

      context 'when time_entrys overlap' do
        let(:duplicate_time_entry) { time_entry.dup }
        before { time_entry.save! }

        it { expect(duplicate_time_entry.valid?).to eq false }
        it { expect { duplicate_time_entry.valid? }
          .to change { duplicate_time_entry.errors.messages.count }.by(1) }

        it 'should contain error message' do
          subject.valid?

          expect { duplicate_time_entry.errors.messages[:start_time]
            .to include('time_entries can not overlap') }
        end
      end
    end
  end

  context 'related entry' do
    let(:time_entry) { create(:time_entry, end_time: '00:00') }
    subject { time_entry.related_entry }

    context 'when entry does not have related entry' do
      it { expect(subject).to eq(nil) }
      it { expect { subject }.to_not raise_error }
    end

    context 'when entry has related entry' do
      let(:day) { time_entry.presence_day }
      let(:related_day) do
        create(:presence_day, presence_policy: day.presence_policy, order: day.order + 1)
      end
      let!(:related_entry) { create(:time_entry, presence_day: related_day, start_time: '00:00') }

      it { expect(subject).to eq(related_entry) }
      it { expect { subject }.to_not raise_error }
    end
  end
end
