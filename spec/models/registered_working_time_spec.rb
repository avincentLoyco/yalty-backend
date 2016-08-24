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

          context ' and the time off overlaps a time entry' do
            it { expect(subject).to eq false  }
            it { expect { subject }.to change { registered_working_time.errors.messages[:date] }
              .to include('working time day can not overlap with existing time off') }
          end

          context 'and the time off does not overlaps a time entry' do
            let(:time_entries) { [] }

            it { expect(subject).to eq true  }
            it { expect { subject }.to_not change { registered_working_time.errors.messages.count } }
          end
        end
      end
    end
  end

  context '#scopes' do
    context '.not_schedule_generated_in_day_range' do
      let(:employee) { create(:employee) }
      let(:end_date) { Date.new(2015, 1, 6) }
      let!(:time_entries) do
        ['1/1/2015', '3/1/2015', '4/1/2015'].map do |date|
          create(:registered_working_time, date: date, employee: employee)
        end
      end

      subject { RegisteredWorkingTime.for_employee_in_day_range(employee.id, start_date, end_date) }

      context 'when there are time entries in date range' do
        let(:start_date) { Date.new(2014, 12, 30) }
        let(:end_date) { Date.new(2015, 1, 3) }

        it { expect(subject).to_not include(time_entries.last) }
        it { expect(subject).to include(time_entries.first) }
        it { expect(subject).to include(time_entries.second) }

        it { expect(subject.length).to eq 2 }
      end

      context 'when there is no time entries in date range' do
        let(:start_date) { Date.new(2015, 1, 5) }

        it { expect(subject).to eq([]) }

        it { expect(subject.length).to eq 0 }
      end
    end

    context 'registered working times by employee and by account' do
      let(:account)         { create(:account) }
      let(:first_employee)  { create(:employee, account: account) }
      let(:second_employee) { create(:employee, account: account) }

      before 'create registered working times' do
        [Time.zone.now, 3.days.from_now, 2.days.from_now].each do |date|
          create(:registered_working_time, employee: first_employee, date: date)
        end

        [Time.zone.now, 3.days.from_now, 2.days.from_now].each do |date|
          create(:registered_working_time, employee: second_employee, date: date)
        end
      end

      context '.manually_created_by_employee_ordered' do
        let(:registered_working_times_from_scope) do
          described_class.manually_created_by_employee_ordered(first_employee.id)
        end

        let(:employee_ids_from_scope) do
          registered_working_times_from_scope.pluck(:employee_id).uniq
        end

        it 'returns only registered_working_times for an employee' do
          expect(registered_working_times_from_scope.size).to eq(3)
          expect(employee_ids_from_scope.size).to eq(1)
          expect(employee_ids_from_scope.first).to eq(first_employee.id)
        end
      end

      context '.manually_created_by_account_ordered' do
        let(:registered_working_times_from_scope) do
          described_class.manually_created_by_account_ordered(account.id)
        end

        let(:account_ids_from_scope) { registered_working_times_from_scope.pluck(:account_id).uniq }

        it 'returns only registered_working_times for an account' do
          expect(registered_working_times_from_scope.size).to eq(6)
          expect(account_ids_from_scope.size).to eq(1)
          expect(account_ids_from_scope.first).to eq(account.id)
        end
      end

      context 'manually_created_ratio_per_employee' do
        subject(:manually_created_ratio_per_employee) do
          described_class.manually_created_ratio_per_employee(first_employee.id)
        end

        context 'when all registered_working_times are created manually' do
          it { expect(manually_created_ratio_per_employee).to eq(100.0) }
        end

        context 'when half of registered_working_times are created from schedule' do
          before 'create registered_working_times from schedule' do
            [4.days.from_now, 5.days.from_now, 6.days.from_now].each do |date|
              create(:schedule_generated_working_time, employee: first_employee, date: date)
            end
          end

          it { expect(manually_created_ratio_per_employee).to eq(50.0) }
        end
      end

      context 'manually_created_ratio_per_account' do
        subject(:manually_created_ratio_per_account) do
          described_class.manually_created_ratio_per_account(account.id)
        end

        context 'when all registered_working_times are created manually' do
          it { expect(manually_created_ratio_per_account).to eq(100.0) }
        end

        context 'when some of registered_working_times are created from schedule' do
          before 'create registered_working_times from schedule' do
            [4.days.from_now, 5.days.from_now, 6.days.from_now].each do |date|
              create(:schedule_generated_working_time, employee: first_employee, date: date)
            end
          end

          it { expect(manually_created_ratio_per_account).to eq(66.67) }
        end
      end
    end
  end

  context 'callbacks' do
    context '.trigger_intercom_update' do
      let(:account) { create(:account) }
      let(:employee) { create(:employee, account: account) }

      subject(:create_registered_working_time) do
        create(:registered_working_time, employee: employee)
      end

      it 'should trigger intercom update on account' do
        expect(account).to receive(:create_or_update_on_intercom).with(true)
        create_registered_working_time
      end

      context 'with user' do
        let(:user) { create(:account_user, account: account) }
        let(:employee) { create(:employee, account: account, user: user) }

        it 'should trigger intercom update on user' do
          expect(user).to receive(:create_or_update_on_intercom).with(true)
          create_registered_working_time
        end
      end

      context 'without user' do
        it 'should not trigger intercom update on user' do
          expect_any_instance_of(Account::User)
            .not_to receive(:create_or_update_on_intercom).with(true)
          create_registered_working_time
        end
      end
    end
  end
end
