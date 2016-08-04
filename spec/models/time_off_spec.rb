require 'rails_helper'

RSpec.describe TimeOff, type: :model do
  include_context 'shared_context_account_helper'

  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:start_time).of_type(:datetime).with_options(null: false) }
  it { is_expected.to have_db_column(:end_time).of_type(:datetime).with_options(null: false) }
  it { is_expected.to have_db_column(:employee_id).of_type(:uuid).with_options(null: false) }
  it { is_expected.to have_db_column(:time_off_category_id)
    .of_type(:uuid).with_options(null: false) }

  it { is_expected.to have_db_index(:time_off_category_id) }
  it { is_expected.to have_db_index(:employee_id) }

  it { is_expected.to belong_to(:employee) }
  it { is_expected.to belong_to(:time_off_category) }
  it { is_expected.to have_one(:employee_balance) }

  it { is_expected.to validate_presence_of(:start_time) }
  it { is_expected.to validate_presence_of(:end_time) }
  it { is_expected.to validate_presence_of(:time_off_category_id) }
  it { is_expected.to validate_presence_of(:employee_id) }

  context 'validations' do
    let(:employee_policy) { build(:employee_time_off_policy) }
    before do
      allow_any_instance_of(Employee)
        .to receive(:active_policy_in_category_at_date) { employee_policy }
    end

    context '#start_time_after_employee_creation' do
      subject { build(:time_off, start_time: effective_at) }

      context 'with invalid data' do
        let(:effective_at) { Time.now - 10.years }

        it { expect(subject.valid?).to eq false }
        it { expect { subject.valid? }.to change { subject.errors.messages[:start_time] }
          .to include('Can not be added before employee start date') }
      end

      context 'with valid params' do
        let(:effective_at) { Time.now - 3.years }

        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
      end
    end

    context '#end_time_after_start_time' do
      subject { build(:time_off, end_time: end_time)  }

      context 'when valid data' do
        let(:end_time) { Time.now + 1.month }

        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.messages } }
      end

      context 'when invalid data' do
        let(:end_time) { Time.now - 1.month }

        it { expect(subject.valid?).to eq false }
        it { expect { subject.valid? }.to change { subject.errors.messages[:end_time] } }
      end
    end

    context '#time_off_policy_presence' do
      subject { build(:time_off) }

      context 'with valid data' do
        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.messages } }
      end

      context 'with invalid data' do
        before do
          allow_any_instance_of(Employee)
            .to receive(:active_policy_in_category_at_date) { nil }
        end

        it { expect(subject.valid?).to eq false }
        it { expect { subject.valid? }.to change { subject.errors.messages[:employee] } }
      end
    end

    context '#does_not_overlap_with_registered_working_times' do
      let(:employee) { create(:employee) }
      let!(:registered_working_time) { create(:registered_working_time, time_entries: time_entries , date: date, employee: employee) }
      let(:time_entries) {[{ start_time: '10:00', end_time: '14:00' }, { start_time: '15:00', end_time: '20:00' }]}
      let(:date) { Date.new(2016,1,1) }

      subject do
        build(:time_off, start_time: Time.zone.local(2016,1,1,2,0,0), end_time: Time.zone.local(2016,1,3,4,0,0) , employee_id: employee.id)
      end

      shared_examples 'TimeOff overlaps with RegisteredWorkingTime' do
        it { expect(subject.valid?).to eq false }
        it { expect { subject.valid? }.to change { subject.errors.messages[:start_time] }
          .to include "Overlaps with registered working time on #{date}" }
        it { expect { subject.valid? }.to change { subject.errors.messages[:end_time] }
          .to include "Overlaps with registered working time on #{date}" }
      end

      context 'when overlapping occurs on the' do
        context 'in the middle day of time off' do
          let(:date) { Date.new(2016,1,2) }
          let(:time_entries) { [{ start_time: '1:00', end_time: '2:00' }] }

          it_behaves_like 'TimeOff overlaps with RegisteredWorkingTime'
        end

        context 'first day of time off' do
          let(:time_entries) { [{ start_time: '00:00', end_time: '24:00' }] }

          it_behaves_like 'TimeOff overlaps with RegisteredWorkingTime'
        end

        context 'on the last day of time off' do
          let(:date) { Date.new(2016,1,3) }
          let(:time_entries) { [{ start_time: '0:00', end_time: '24:00' }] }

          it_behaves_like 'TimeOff overlaps with RegisteredWorkingTime'
        end
      end

      context 'when more than one time entry overlaps in one day' do
        subject do
          build(:time_off, start_time: Time.zone.local(2016,1,1,2,0,0), end_time: Time.zone.local(2016,1,1,5,0,0), employee_id: employee.id)
        end
        let(:time_entries) {[{ start_time: '1:00', end_time: '3:00' }, { start_time: '4:00', end_time: '6:00' }]}

        it_behaves_like 'TimeOff overlaps with RegisteredWorkingTime'
      end

      context 'when time off duration is of one day' do
        subject do
          build(:time_off, start_time: Time.zone.local(2016,1,1,2,0,0), end_time: Time.zone.local(2016,1,1,4,0,0) , employee_id: employee.id)
        end
        let(:time_entries) { [{ start_time: '1:00', end_time: '3:00' }] }

        it_behaves_like 'TimeOff overlaps with RegisteredWorkingTime'
      end

      context 'when they do not overlap' do

        context 'before the time entry'  do
          let(:time_entries) { [{ start_time: '0:00', end_time: '1:00' }] }

          it { expect(subject.valid?).to eq true }
        end
        context 'after the time entry'  do
          let(:date) { Date.new(2016,1,3) }
          let(:time_entries) { [{ start_time: '4:00', end_time: '5:00' }] }

          it { expect(subject.valid?).to eq true }
        end

        context 'when time off duration is of one day' do
          subject do
            build(:time_off, start_time: Time.zone.local(2016,1,1,2,0,0), end_time: Time.zone.local(2016,1,1,4,0,0) , employee_id: employee.id)
          end
          let(:time_entries) { [{ start_time: '1:00', end_time: '2:00' }] }

          it { expect(subject.valid?).to eq true }
        end
      end
    end

    context '#does_not_overlap_with_other_users_time_offs' do
      let(:employee) { create(:employee) }
      subject do
        build(:time_off, start_time: '1/1/2016', end_time: '5/1/2016', employee_id: employee.id)
      end

      context 'when there are no another time offs' do
        it { expect(subject.valid?).to eq true }
        it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
      end

      context 'when there is another time off' do
        let(:start_time) { '6/1/2016' }
        let(:end_time) { '10/1/2016' }
        let!(:time_off) do
          create(:time_off, start_time: start_time, end_time: end_time, employee: employee)
        end

        context 'and it does not overlaps' do
          let(:start_time) { '6/1/2016' }

          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }

          context 'end_time eqal existing time off start_time' do
            let(:start_time) { '5/1/2016' }

            it { expect(subject.valid?).to eq true }
            it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
          end

          context 'start_time equal existing time off end_time' do
            let(:start_time) { '31/12/2015' }
            let(:end_time) { '1/1/2016' }

            it { expect(subject.valid?).to eq true }
            it { expect { subject.valid? }.to_not change { subject.errors.messages.count } }
          end
        end

        context 'and it overlaps' do
          context 'start_time and end_time are in existing time off period' do
            let(:start_time) { '2/1/2016' }
            let(:end_time) { '4/1/2016' }

            it { expect(subject.valid?).to eq false }
            it { expect { subject.valid? }.to change { subject.errors.messages[:start_time] }
              .to include 'Time off in period already exist' }
          end

          context 'start_time and end_time are in existing time off period' do
            let(:start_time) { '1/1/2016' }
            let(:end_time) { '5/1/2016' }

            it { expect(subject.valid?).to eq false }
            it { expect { subject.valid? }.to change { subject.errors.messages[:start_time] }
              .to include 'Time off in period already exist' }
          end

          context 'start_time in exsiting time off period' do
            let(:start_time) { '3/1/2016' }

            it { expect(subject.valid?).to eq false }
            it { expect { subject.valid? }.to change { subject.errors.messages[:start_time] }
              .to include 'Time off in period already exist' }
          end

          context 'end_time in existing time off period' do
            let(:start_time) { '31/12/2015' }
            let(:end_time) { '3/1/2016' }

            it { expect(subject.valid?).to eq false }
            it { expect { subject.valid? }.to change { subject.errors.messages[:start_time] }
              .to include 'Time off in period already exist' }
          end
        end
      end
    end
  end

  context 'scopes' do
    include_context 'shared_context_timecop_helper'

    context '#for_employee_in_period' do
      subject { TimeOff.for_employee_in_period(employee, start_date, end_date).pluck(:id) }
      let(:start_date) { Time.now + 1.day }
      let(:end_date) { Time.now + 4.days }
      let(:employee) { create(:employee) }

      context 'when employee does not have time offs' do
        it { expect(subject.size).to eq 0 }
      end

      context 'when employee has time_offs in period' do
        context 'when time offs start or end dates are in the scope' do
          let!(:time_offs) do
            [[Time.now, Time.now + 1.day], [Time.now + 2.days, Time.now + 3.days],
             [Time.now + 4.days, Time.now + 5.days]].map do |start_time, end_time|
               create(:time_off, employee: employee, start_time: start_time, end_time: end_time)
             end
          end
          it { expect(subject.size).to eq 3 }

          it { expect(subject).to include(time_offs.first.id) }
          it { expect(subject).to include(time_offs.second.id) }
          it { expect(subject).to include(time_offs.last.id) }

          context 'while time off is not in the scope' do
            let(:start_date) { Time.now + 2.days }

            it { expect(subject.size).to eq 2 }

            it { expect(subject).to include(time_offs.second.id) }
            it { expect(subject).to include(time_offs.last.id) }

            it { expect(subject).to_not include(time_offs.first.id) }
          end
        end

        context 'when time offs start and end dates are outside the scope' do
          let!(:time_off) do
            create(:time_off,
              start_time: Time.now + 1.day, end_time: Time.now + 4.days, employee: employee)
          end

          it { expect(subject.size).to eq 1 }
          it { expect(subject).to include(time_off.id) }
        end
      end
    end

    context 'vacations and not_vacations' do
      let(:vacation_category) { create(:time_off_category, name: 'vacation') }

      let!(:vacation_time_off_first) { create(:time_off, time_off_category: vacation_category) }
      let!(:vacation_time_off_second) { create(:time_off, time_off_category: vacation_category) }

      let!(:different_time_off_first) { create(:time_off) }
      let!(:different_time_off_second) { create(:time_off) }

      let(:vacation_time_offs_ids) { [vacation_time_off_first.id, vacation_time_off_second.id] }
      let(:different_time_offs_ids) { [different_time_off_first.id, different_time_off_second.id] }

      context '.vacations' do
        it 'return time_off with \'vacation\' category' do
          expect(described_class.vacations.pluck(:id)).to match_array(vacation_time_offs_ids)
        end
      end

      context '.not_vacations' do
        it 'return time_off without \'vacation\' category' do
          expect(described_class.not_vacations.pluck(:id)).to match_array(different_time_offs_ids)
        end
      end
    end

    context '.last_for_employee' do
      let(:employee) { create(:employee) }

      before 'create time_offs in order' do
        Timecop.travel(2016, 1, 1, 0, 0)
        create(:time_off, employee: employee, start_time: Time.zone.now, end_time: 1.day.from_now)
        Timecop.travel(2016, 4, 4, 0, 0)
        create(:time_off, employee: employee, start_time: Time.zone.now, end_time: 1.day.from_now)
      end

      it 'returns last created time_off for an employee' do
        expect(described_class.for_employee(employee.id).count).to eq(2)
      end
    end

    context '.for_account' do
      let(:account) { create(:account) }
      let(:category) { create(:time_off_category, account: account) }
      let(:employee_first) { create(:employee, account: account) }
      let(:employee_second) { create(:employee, account: account) }

      before 'create time_offs in order' do
        create(
          :time_off,
          employee: employee_first,
          start_time: Time.zone.now,
          end_time: 1.day.from_now,
          time_off_category: category,
        )
        create(
          :time_off,
          employee: employee_first,
          start_time: 1.day.from_now,
          end_time: 2.day.from_now,
          time_off_category: category,
        )
        create(
          :time_off,
          employee: employee_second,
          start_time: Time.zone.now,
          end_time: 1.day.from_now,
        )
        create(
          :time_off,
          employee: employee_second,
          start_time: 1.day.from_now,
          end_time: 2.day.from_now,
        )
      end

      it 'returns last created time_off for an employee' do
        expect(described_class.for_account(account.id).count).to eq(2)
      end
    end
  end

  context 'callbacks' do
    context '.trigger_intercom_update' do
      let(:account) { create(:account) }
      let(:category) { create(:time_off_category, account: account) }
      let(:employee) { create(:employee, account: account) }

      subject(:create_time_off) do
        create(:time_off, employee: employee, time_off_category: category)
      end

      it 'should trigger intercom update on account' do
        expect(account).to receive(:create_or_update_on_intercom).with(true)
        create_time_off
      end

      context 'with user' do
        let(:user) { create(:account_user, account: account) }
        let(:employee) { create(:employee, account: account, user: user) }

        it 'should trigger intercom update on user' do
          expect(user).to receive(:create_or_update_on_intercom).with(true)
          create_time_off
        end
      end

      context 'without user' do
        it 'should not trigger intercom update on user' do
          expect_any_instance_of(Account::User)
            .not_to receive(:create_or_update_on_intercom).with(true)
          create_time_off
        end
      end
    end
  end
 end
