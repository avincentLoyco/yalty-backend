require 'rails_helper'

RSpec.describe TimeEntry, type: :model do
  it { is_expected.to have_db_column(:start_time).of_type(:string) }
  it { is_expected.to have_db_column(:end_time).of_type(:string) }
  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:presence_day_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:duration).of_type(:integer) }

  it { is_expected.to belong_to(:presence_day) }

  it { is_expected.to validate_presence_of(:start_time) }
  it { is_expected.to validate_presence_of(:end_time) }
  it { is_expected.to validate_presence_of(:presence_day_id) }
  it { is_expected.to validate_presence_of(:duration) }

  context 'before validation calback' do
    subject { TimeEntry.new(start_time: '14:00', end_time: '16:00') }

    it { expect { subject.valid? }.to change { subject.start_time }.to('14:00:00') }
    it { expect { subject.valid? }.to change { subject.end_time }.to('16:00:00') }
    it { expect { subject.valid? }.to change { subject.duration }.from(0).to(120) }
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

    context '#time_entry_not_reserved' do
      let(:policy) { create(:presence_policy) }
      let(:first_day) { create(:presence_day, order: 1, presence_policy: policy) }
      let(:second_day) { create(:presence_day, order: 2, presence_policy: policy) }
      let!(:time_entry) do
        create(:time_entry, presence_day: day, start_time: '4:00', end_time: '2:00')
      end
      subject do
        build(:time_entry, presence_day: sub_day, start_time: sub_start, end_time: sub_end)
      end

      before(:each) do
        first_day.reload
        second_day.reload
      end

      shared_examples 'Time Entries Do Not Overlap' do
        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }
          .to_not change { subject.errors.messages.count } }
      end

      shared_examples 'Time Entries Overlap' do
        it { expect(subject.valid?).to eq false }
        it { expect { subject.valid? }
          .to change { subject.errors.messages.count }.by(1) }

        context 'response body' do
          before { subject.valid? }

          it { expect(subject.errors.messages[:start_time])
            .to include('time_entries can not overlap') }
        end
      end

      context 'when time entry do not overlap' do
        let(:sub_start) { '2:30' }
        let(:sub_end) { '10:00' }

        context 'with current day entry' do
          context 'and different hours' do
            let(:day) { first_day }
            let(:sub_day) { first_day }
            let(:sub_end) { '3:30' }

            it_behaves_like 'Time Entries Do Not Overlap'
          end

          context 'and end hours overlap' do
            let(:day) { first_day }
            let(:sub_day) { first_day }
            let(:sub_end) { '4:00' }

            it_behaves_like 'Time Entries Do Not Overlap'
          end
        end

        context 'with previous day entry' do
          let(:day) { first_day }
          let(:sub_day) { second_day }

          it_behaves_like 'Time Entries Do Not Overlap'
        end

        context 'with next day entry' do
          let(:day) { second_day }
          let(:sub_day) { first_day }

          it_behaves_like 'Time Entries Do Not Overlap'
        end
      end

      context 'when time entry overlap' do
        let(:sub_start) { '00:00' }
        let(:sub_end) { '6:00' }

        context 'with current day entry' do
          let(:day) { first_day }
          let(:sub_day) { first_day }
          let(:sub_end) { '6:00' }

          it_behaves_like 'Time Entries Overlap'
        end

        context 'with previous day entry' do
          context 'and new entry day order is 1' do
            let(:sub_day) { first_day }
            let(:day) { second_day }

            it_behaves_like 'Time Entries Overlap'
          end

          context 'and new entry order not 1' do
            let(:sub_day) { second_day }
            let(:day) { first_day }

            it_behaves_like 'Time Entries Overlap'
          end
        end

        context 'with next day entry' do
          let(:sub_start) { '15:00' }
          let(:sub_end) { '5:00' }

          context 'and new entry order is last in policy' do
            let(:sub_day) { second_day }
            let(:day) { first_day }

            it_behaves_like 'Time Entries Overlap'
          end

          context 'and new entry order is not last in policy' do
            let(:sub_day) { first_day }
            let(:day) { second_day }

            it_behaves_like 'Time Entries Overlap'
          end
        end
      end
    end
  end
end
