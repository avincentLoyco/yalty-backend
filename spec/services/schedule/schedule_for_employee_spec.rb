require 'rails_helper'

RSpec.describe ScheduleForEmployee, type: :service do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  before do
    employee.first_employee_working_place.update!(effective_at: '1/1/2015')
    employee.first_employee_working_place.working_place.update!(holiday_policy: policy)
    presence_days.map do |presence_day|
      create(:time_entry, presence_day: presence_day, start_time: '1:00', end_time: '6:00')
    end
  end

  let(:employee) { create(:employee) }
  subject { described_class.new(employee, start_date, end_date).call }

  describe '#call' do
    let(:policy) { create(:holiday_policy, country: 'ch', region: 'zh') }
    let(:presence_policy) { create(:presence_policy, account: account) }
    let(:account) { employee.account }
    let(:start_date) { Date.new(2015, 12, 26) }
    let(:end_date) { Date.new(2015, 12, 30) }
    let(:presence_days)  do
      [1,2,3,5,6,7].map do |i|
        create(:presence_day, order: i, presence_policy: presence_policy)
      end
    end

    context 'when they are holidays, time offs and time entries in the range' do
      let!(:epp) do
        create(:employee_presence_policy,
          presence_policy: presence_policy,
          employee: employee,
          effective_at: start_date
        )
      end
      let!(:time_offs) do
        time = Time.now - 2.days
        time_offs_dates =
          [
            [Time.now - 8.days + 12.hours, Time.now - 5.days + 12.hours],
            [time, time + 2.hours],
            [time + 3.hours, time + 4.hours],
            [time + 5.hours, time + 7.hours]
          ]
        time_offs_dates.map do |start_time, end_time|
           create(:time_off, employee: employee, start_time: start_time, end_time: end_time)
        end
      end

      it { expect(subject.size).to eq 5 }
      it 'should have valid response' do
        expect(subject).to eq(
          [
            {
              date: '2015-12-26',
              time_entries: [
                {
                  type: 'holiday',
                  name: 'st_stephens_day'
                }
              ]
            },
            {
              date: '2015-12-27',
              time_entries: [
                {
                  type: 'time_off',
                  name: time_offs.first.time_off_category.name,
                  start_time: '00:00:00',
                  end_time: '12:00:00'
                }
              ]
            },
            {
              date: '2015-12-28',
              time_entries: [
                {
                  type: 'working_time',
                  start_time: '01:00:00',
                  end_time: '06:00:00'
                }
              ]
            },
            {
              date: '2015-12-29',
              time_entries: [
                {
                  type: 'working_time',
                  start_time: '01:00:00',
                  end_time: '06:00:00'
                }
              ]
            },
            {
              date: '2015-12-30',
              time_entries: [
                {
                  type: 'time_off',
                  name: time_offs.first.time_off_category.name,
                  start_time: '00:00:00',
                  end_time: '02:00:00'
                },
                {
                  type: 'time_off',
                  name: time_offs.first.time_off_category.name,
                  start_time: '03:00:00',
                  end_time: '04:00:00'
                },
                {
                  type: 'time_off',
                  name: time_offs.first.time_off_category.name,
                  start_time: '05:00:00',
                  end_time: '07:00:00'
                },
                {
                  type: 'working_time',
                  start_time: '02:00:00',
                  end_time: '03:00:00'
                },
                {
                  type: 'working_time',
                  start_time: '04:00:00',
                  end_time: '05:00:00'
                }
              ]
            }
          ]
        )
      end
    end

    context 'when there are no time entries, time off and holidays' do
      let(:start_date) { Date.new(2015, 12, 27) }

      it { expect(subject.size).to eq 4 }
      it 'should have valid response' do
        expect(subject).to eq(
          [
            {
              date: '2015-12-27',
              time_entries: []
            },
            {
              date: '2015-12-28',
              time_entries: []
            },
            {
              date: '2015-12-29',
              time_entries: []
            },
            {
              date: '2015-12-30',
              time_entries: []
            }
          ]
        )
      end
    end
  end
end
