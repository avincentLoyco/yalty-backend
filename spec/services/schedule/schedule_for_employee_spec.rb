require 'rails_helper'

RSpec.describe ScheduleForEmployee, type: :service do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  before do
    employee.first_employee_working_place.update!(effective_at: '1/1/2015')
    employee.first_employee_working_place.working_place.update!(holiday_policy: policy)
  end

  let(:employee) { create(:employee) }
  subject { described_class.new(employee, start_date, end_date).call }

  describe '#call' do
    context 'when they are holidays in the range' do
      let(:start_date) { Date.new(2015, 12, 24) }
      let(:end_date) { Date.new(2016, 1, 1) }
      let(:policy) { create(:holiday_policy, country: 'ch', region: 'zh') }
      let(:account) { employee.account }
      let(:presence_policy) { create(:presence_policy, account: account) }
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
      let(:presence_days)  do
        [1,2,3,5,6,7].map do |i|
          create(:presence_day, order: i, presence_policy: presence_policy)
        end
      end
      before(:each) do
        presence_days.map do |presence_day|
          create(:time_entry, presence_day: presence_day, start_time: '1:00', end_time: '6:00')
        end
      end

      it { expect(subject).to eq 'trolo'}
    end

    context 'when they are no holidays in the range' do
    end
  end
end
