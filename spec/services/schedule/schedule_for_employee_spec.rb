require 'rails_helper'

RSpec.describe ScheduleForEmployee, type: :service do
  include_context 'shared_context_account_helper'
  before do
    Timecop.freeze(2015, 12, 28, 0, 0)
  end

  after do
    Timecop.return
  end

  before do
    employee.first_employee_event.update!(effective_at: '1/1/2015')
    employee.first_employee_working_place.update!(effective_at: '1/1/2015')
    employee.first_employee_working_place.working_place.update!(holiday_policy: policy)
    presence_days.map do |presence_day|
      create(:time_entry, presence_day: presence_day, start_time: '1:00', end_time: '6:00')
    end
  end

  let(:policy) { create(:holiday_policy, country: 'ch', region: 'zh') }
  let(:employee) { create(:employee) }
  subject { described_class.new(employee, start_date, end_date).call }

  describe '#call' do
    let(:presence_policy) { create(:presence_policy, account: account) }
    let(:account) { employee.account }
    let(:start_date) { Date.new(2015, 12, 25) }
    let(:end_date) { Date.new(2015, 12, 31) }
    let!(:epp) do
      create(:employee_presence_policy,
        presence_policy: presence_policy,
        employee: employee,
        effective_at: start_date
      )
    end
    let(:presence_days)  do
      [1,2,3,4,5,6,7].map do |i|
        create(:presence_day, order: i, presence_policy: presence_policy)
      end
    end

    context 'when they are holidays, time offs, working_times and time entries in the range' do
      let!(:time_offs) do
        time = Time.now + 2.days
        time_offs_dates =
          [
            [Time.now - 2.days + 12.hours, Time.now - 1.day],
            [Time.now - 1.day + 5.hours, Time.now - 1.day + 10.hours],
            [time, time + 2.hours],
            [time + 3.hours, time + 4.hours],
            [time + 5.hours, time + 7.hours],
          ]
        time_offs_dates.map do |start_time, end_time|
           create(:time_off, employee: employee, start_time: start_time, end_time: end_time)
        end
      end
      let!(:working_times) do
        [Time.now - 3.days, Time.now, Time.now - 1.day].map do |date|
          create(:registered_working_time, employee: employee, date: date)
        end
      end
      let!(:working_time) do
        create(:registered_working_time, employee: employee, date: Time.now + 3.day, time_entries: [])
      end

      it { expect(subject.size).to eq 7 }
      it 'should have valid response' do
        expect(subject).to match_hash(
          [
            {
              date: '2015-12-25',
              time_entries: [
                {
                  type: 'holiday',
                  name: 'christmas'
                },
                {
                  type: 'working_time',
                  start_time: '10:00:00',
                  end_time: '14:00:00'
                },
                {
                  type: 'working_time',
                  start_time: '15:00:00',
                  end_time: '20:00:00'
                }
              ]
            },
            {
              date: '2015-12-26',
              time_entries: [
                {
                  type: 'time_off',
                  name: time_offs.first.time_off_category.name,
                  start_time: '12:00:00',
                  end_time: '24:00:00'
                },
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
                  start_time: '05:00:00',
                  end_time: '10:00:00'
                },
                {
                  type: 'working_time',
                  start_time: '10:00:00',
                  end_time: '14:00:00'
                },
                {
                  type: 'working_time',
                  start_time: '15:00:00',
                  end_time: '20:00:00'
                }
              ]
            },
            {
              date: '2015-12-28',
              time_entries: [
                {
                  type: 'working_time',
                  start_time: '10:00:00',
                  end_time: '14:00:00'
                },
                {
                  type: 'working_time',
                  start_time: '15:00:00',
                  end_time: '20:00:00'
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
                  start_time: '05:00:00',
                  end_time: '07:00:00'
                },
                {
                  type: 'working_time',
                  start_time: '02:00:00',
                  end_time: '03:00:00'
                },
                {
                  type: 'time_off',
                  name: time_offs.first.time_off_category.name,
                  start_time: '03:00:00',
                  end_time: '04:00:00'
                },
                {
                  type: 'working_time',
                  start_time: '04:00:00',
                  end_time: '05:00:00'
                }
              ]
            },
            {
              date: '2015-12-31',
              time_entries: []
            }
          ]
        )
      end
    end

    context 'when there are time offs after already processed time entry' do
      let(:start_date) { Date.new(2015, 12, 29) }
      let(:end_date) { Date.new(2015, 12, 29) }
      let!(:time_offs) do
        time = Time.now + 1.day
        time_offs_dates =
          [
            [time + 5.hours, time + 6.hours],
            [time + 7.hours, time + 10.hours],
          ]
        time_offs_dates.map do |start_time, end_time|
           create(:time_off, employee: employee, start_time: start_time, end_time: end_time)
        end
      end

      it 'should have valid response' do
        expect(subject).to match_hash(
          [
            {
               date: "2015-12-29",
               time_entries: [
                 {
                   type: "time_off",
                   name: time_offs.first.time_off_category.name,
                   start_time: "05:00:00",
                   end_time: "06:00:00"
                 },
                 {
                   type: "time_off",
                   name: time_offs.first.time_off_category.name,
                   start_time: "07:00:00",
                   end_time: "10:00:00"
                 },
                 {
                   type: "working_time",
                   start_time: "01:00:00",
                   end_time: "05:00:00"
                 }
               ]
             }
          ]
        )
      end
    end

    context 'when time off starts at the beggining of the day and ends at the end' do
      before { TimeEntry.destroy_all }
      let(:start_date) { Date.new(2016, 1, 4) }
      let(:end_date) { Date.new(2016, 1, 6) }
      let!(:time_off) do
        create(:time_off,
          employee: employee, start_time: Time.now + 7.days, end_time: Time.now + 9.days)
      end

      it { expect(subject.size).to eq 3 }
      it 'should have valid response' do
        expect(subject).to match_hash(
          [
            {
              date: '2016-01-04',
              time_entries: [
                {
                  type: 'time_off',
                  name: time_off.time_off_category.name,
                  start_time: '00:00:00',
                  end_time: '24:00:00'
                }
              ]
            },
            {
              date: '2016-01-05',
              time_entries: [
                {
                  type: 'time_off',
                  name: time_off.time_off_category.name,
                  start_time: '00:00:00',
                  end_time: '24:00:00'
                }
              ]
            },
            {
              date: '2016-01-06',
              time_entries: []
            }
          ]
        )
      end
    end

    context 'when there are time offs before already processed time entry' do
      let(:start_date) { Date.new(2015, 12, 29) }
      let(:end_date) { Date.new(2015, 12, 29) }
      let!(:time_offs) do
        time = Time.now + 1.day
        time_offs_dates =
          [
            [time + 1.hour, time + 2.hours],
            [time + 7.hours, time + 10.hours],
          ]
        time_offs_dates.map do |start_time, end_time|
           create(:time_off, employee: employee, start_time: start_time, end_time: end_time)
        end
      end

      it 'should have valid response' do
        expect(subject).to match_hash(
          [
            {
               date: "2015-12-29",
               time_entries: [
                 {
                   type: "time_off",
                   name: time_offs.first.time_off_category.name,
                   start_time: "01:00:00",
                   end_time: "02:00:00"
                 },
                 {
                   type: "time_off",
                   name: time_offs.first.time_off_category.name,
                   start_time: "07:00:00",
                   end_time: "10:00:00"
                 },
                 {
                   type: "working_time",
                   start_time: "02:00:00",
                   end_time: "06:00:00"
                 }
               ]
             }
          ]
        )
      end
    end

    context 'when there are no time entries, time off and holidays' do
      before { epp.destroy! }
      let(:start_date) { Date.new(2015, 12, 27) }

      it { expect(subject.size).to eq 5 }
      it 'should have valid response' do
        expect(subject).to match_hash(
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
            },
            {
              date: '2015-12-31',
              time_entries: []
            }
          ]
        )
      end
    end
  end
end
