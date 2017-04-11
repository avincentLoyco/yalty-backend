require 'rails_helper'
require 'rake'

RSpec.describe 'repair_overlaping_time_offs', type: :rake do
  include_context 'rake'

  subject { rake['repair_overlaping_time_offs'].invoke }

  let!(:account)           { create(:account) }
  let(:employee)           { create(:employee, account: account) }
  let!(:vacation_category) { create(:time_off_category, account: account) }

  let(:vacation_balancer_policy) do
    create(:time_off_policy, :with_end_date,
      time_off_category: vacation_category, amount: 200, years_to_effect: 1)
  end

  let!(:presence_policy) { create(:presence_policy, :with_time_entries, account: account) }

  let!(:employee_presence_policy) do
    create(:employee_presence_policy,
      employee: employee, effective_at: start_time - 5.months, presence_policy: presence_policy)
  end

  let(:start_time) { Time.new(2016, 6, 6, 14, 0, 0) }

  let!(:time_off) do
    create(:time_off,
      employee: employee, time_off_category: vacation_category,
      start_time: start_time, end_time: start_time + 12.days)
  end

  context 'overlaping time offs' do
    context 'without overlaping time offs' do
      before do
        [
          { start: start_time + 14.days, end: start_time + 17.days },
          { start: start_time - 11.days, end: start_time - 9.days }
        ].each do |time|
          time_off = build(:time_off,
            employee: employee, time_off_category: vacation_category,
            start_time: time[:start], end_time: time[:end])
          time_off.save(validate: false)
        end
      end

      it { expect { subject }.not_to change { employee.employee_balances.count } }
      it { expect { subject }.not_to change { employee.time_offs.count } }
    end

    context 'with overlaping time offs' do
      before do
        [
          { start: start_time + 1.day, end: start_time + 2.days },
          { start: start_time + 4.days, end: start_time + 6.days }
        ].each do |time|
          time_off = build(:time_off,
            employee: employee, time_off_category: vacation_category,
            start_time: time[:start], end_time: time[:end])
          time_off.save(validate: false)
        end
      end

      it { expect { subject }.to change { employee.employee_balances.count } }
      it { expect { subject }.to change { employee.time_offs.count } }

      context 'Leaves dominant balance' do
        before { subject }

        it { expect(employee.time_offs.ids).to eq([time_off.id])}
        it { expect(employee.employee_balances.ids).to eq([time_off.employee_balance.id]) }
      end
    end
  end

  context 'overlaping registered working time' do
    before do
      working_time = build(:registered_working_time,
        employee: employee, date: date, time_entries:
        [
          { start_time: '8:00:00', end_time: '9:00:00' },
          { start_time: '15:00:00', end_time: '16:00:00' }
        ])
      working_time.save(validate: false)
    end
    let(:working_time) { employee.registered_working_times.first }

    context 'when registered working time does not overlap' do
      let(:date) { start_time - 15.days }
      it { expect { subject }.not_to change { working_time.reload.time_entries.count } }
    end

    context 'when registered working time overlaps with time off' do
      let(:date) { start_time }
      it { expect { subject }.to change { working_time.reload.time_entries.count } }
    end
  end
end
