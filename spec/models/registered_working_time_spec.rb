require 'rails_helper'

RSpec.describe RegisteredWorkingTime, type: :model do
  include_context 'shared_context_account_helper'

  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:employee_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:date).of_type(:date) }
  it { is_expected.to have_db_column(:time_entries).of_type(:json).with_options(default: '{}') }
  it { is_expected.to have_db_column(:schedule_generated).of_type(:boolean).with_options(default: false) }

  it { is_expected.to have_db_index([:employee_id, :date]).unique }

  it { is_expected.to belong_to(:employee) }

  shared_examples 'Schedule generated' do
    let(:registered_working_time) do
      build(:registered_working_time, :schedule_generated, time_entries: time_entries)
    end

    it { expect(subject).to eq true }
    it { expect { subject }.to_not change { registered_working_time.errors.messages.count } }
  end

  context 'validations' do
    subject { registered_working_time.valid? }

    let(:registered_working_time) { build(:registered_working_time, time_entries: time_entries) }
    let(:time_entries) do
      [{ start_time: '10:00', end_time: '14:00' }, { start_time: '15:00', end_time: '24:00' }]
    end

    context '.time_entries_time_format_valid' do
      context 'when time entries in valid format' do
        it { expect(subject).to eq true }
        it { expect { subject }.to_not change { registered_working_time.errors.messages.count } }
      end

      context 'when time entries in invalid format' do
        let(:time_entries) do
          [{ start_time: 'abc', end_time: '14:00' }, { start_time: '15:00', end_time: 'cba' }]
        end

        it { expect(subject).to eq false  }
        it { expect { subject }.to change { registered_working_time.errors.messages[:time_entries] }
          .to include('time entries must be array of hashes, with start_time and end_time as times') }

        it_behaves_like 'Schedule generated'
      end
    end

    context '.time_entries_smaller_than_one_day' do
      context 'when time entries duration smaller than one day' do
        it { expect(subject).to eq true }
        it { expect { subject }.to_not change { registered_working_time.errors.messages.count } }
      end

      context 'when time entries duration bigger than one day' do
        let(:time_entries) do
          [{ start_time: '00:00', end_time: '22:00' }, { start_time: '22:00', end_time: '2:00' }]
        end

        it { expect(subject).to eq false  }
        it { expect { subject }.to change { registered_working_time.errors.messages[:time_entries] }
          .to include('time_entries can not be longer than one day') }

        it_behaves_like 'Schedule generated'
      end
    end

    context '.time_entries_does_not_overlap' do
      context 'when time entries does not overlap' do
        it { expect(subject).to eq true }
        it { expect { subject }.to_not change { registered_working_time.errors.messages.count } }
      end

      context 'when time entries overlap' do
        context 'time entries start time or end time overlaps' do
          let(:time_entries) do
            [
              { start_time: '7:00', end_time: '11:00' },
              { start_time: '11:00', end_time: '15:00' },
              { start_time: '14:00', end_time: '19:00' }
            ]
          end

          it { expect(subject).to eq false  }
          it { expect { subject }.to change { registered_working_time.errors.messages[:time_entries] }
            .to include('time_entries can not overlap') }

          it_behaves_like 'Schedule generated'
        end

        context 'time entry included in the other' do
          let(:time_entries) do
            [
              { start_time: '7:00', end_time: '11:00' },
              { start_time: '11:00', end_time: '15:00' },
              { start_time: '12:00', end_time: '14:00' }
            ]
          end

          it { expect(subject).to eq false  }
          it { expect { subject }.to change { registered_working_time.errors.messages[:time_entries] }
            .to include('time_entries can not overlap') }

          it_behaves_like 'Schedule generated'
        end
      end
    end

    context '.unique_time_entries' do
      context 'time entries are not uniq' do
        let(:time_entries) do
          [
            { start_time: '7:00', end_time: '11:00' },
            { start_time: '11:00', end_time: '15:00' },
            { start_time: '11:00', end_time: '15:00' }
          ]
        end

        it { expect(subject).to eq false  }
        it { expect { subject }.to change { registered_working_time.errors.messages[:time_entries] }
          .to include('time_entries must be uniq') }

        it_behaves_like 'Schedule generated'
      end
    end

    context '.time_entries_does_not_overlaps_with_time_off' do
      before do
        create(:time_off,
          employee: registered_working_time.employee, start_time: start_time, end_time: end_time)
      end

      let(:start_time) { '2/5/2016' }
      let(:end_time)  { '3/5/2016' }

      context 'when there is no time off in a given date' do
        it { expect(subject).to eq true }
        it { expect { subject }.to_not change { registered_working_time.errors.messages.count } }
      end

      context 'when there is time off for given date' do
        context 'when time off starts at given date' do
          let(:start_time) { '1/5/2016' }

          it { expect(subject).to eq false  }
          it { expect { subject }.to change { registered_working_time.errors.messages[:date] }
            .to include('working time day can not overlap with existing time off') }
        end

        context 'when time off ends in given date' do
          let(:start_time) { '30/4/2016' }
          let(:end_time)  { DateTime.new(2016, 5, 1, 15, 0, 0) }

          it { expect(subject).to eq false  }
          it { expect { subject }.to change { registered_working_time.errors.messages[:date] }
            .to include('working time day can not overlap with existing time off') }
        end

        context 'when time off is for a given date' do
          let(:start_time) { DateTime.new(2016, 5, 1, 0, 0) }
          let(:end_time)  { DateTime.new(2016, 5, 1, 23, 59) }

          it { expect(subject).to eq false  }
          it { expect { subject }.to change { registered_working_time.errors.messages[:date] }
            .to include('working time day can not overlap with existing time off') }

          context 'and it overlaps time entries' do
            let(:start_time) { DateTime.new(2016, 5, 1, 0, 0) }
            let(:end_time)  { DateTime.new(2016, 5, 1, 11, 0) }

            it { expect(subject).to eq false  }
            it { expect { subject }.to change { registered_working_time.errors.messages[:date] }
              .to include('working time day can not overlap with existing time off') }
          end

          context 'and it has the same params as time time entries' do
            let(:start_time) { DateTime.new(2016, 5, 1, 10, 0) }
            let(:end_time)  { DateTime.new(2016, 5, 1, 14, 0) }

            it { expect(subject).to eq false  }
            it { expect { subject }.to change { registered_working_time.errors.messages[:date] }
              .to include('working time day can not overlap with existing time off') }
          end

          context 'and it does not overlaps time entries' do
            let(:start_time) { DateTime.new(2016, 5, 1, 0, 0) }
            let(:end_time)  { DateTime.new(2016, 5, 1, 1, 0) }

            it { expect(subject).to eq true }
            it { expect { subject }.to_not change { registered_working_time.errors.messages.count } }
          end
        end

        context 'when day is in the middle of time off' do
          let(:start_time) { '30/4/2016' }

          it { expect(subject).to eq false  }
          it { expect { subject }.to change { registered_working_time.errors.messages[:date] }
            .to include('working time day can not overlap with existing time off') }
        end
      end
    end
  end
end
