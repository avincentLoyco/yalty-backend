require 'rails_helper'

RSpec.describe CalculateTimeOffBalance, type: :service do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  subject { CalculateTimeOffBalance.new(time_off).call }

  let(:policy) { create(:presence_policy) }
  let(:employee) { create(:employee, :with_policy, presence_policy: policy) }
  let(:category) { employee.employee_time_off_policies.first.time_off_policy.time_off_category }
  let(:time_off) do
    create(:time_off, :with_balance,
      employee: employee, time_off_category: category, start_time: Date.today + 2.day,
      end_time: Date.today + 8.days
    )
  end

  context 'when employee have time_entries in policy' do
    let(:first_day) { create(:presence_day, order: 2, presence_policy: policy) }
    let(:second_day) { create(:presence_day, order: 5, presence_policy: policy) }
    let!(:first_entry) { create(:time_entry, presence_day: first_day) }
    let!(:second_entry) { create(:time_entry, presence_day: second_day) }
    let!(:third_entry) do
      create(:time_entry, presence_day: second_day, start_time: '6:00', end_time: '14:00')
    end

    context 'when time off for few hours' do
      before { time_off.update!(start_time: Date.today, end_time: Date.today + 8.hours) }
      it { expect(subject).to eq 120 }
    end

    context 'when time off shorter than one week' do
      it { expect(subject).to eq 600 }
    end

    context 'when time off longer than one week' do
      before { time_off.update!(end_time: Date.today + 17.days) }

      it { expect(subject).to eq 1200 }
    end

    context 'time off start and ends in the middle of entries' do
      before do
        time_off.update!(
                         start_time: Date.today + 7.hours ,
                         end_time: Date.today + 11.days + 16.hours + 30.minutes
                        )
      end
      it { expect(subject).to eq 1110 }
    end

    context 'and when there are holidays in the time off period' do
      let(:holiday_policy) { create(:holiday_policy, country: 'ch', region: 'zh') }
      before { employee.update!(holiday_policy: holiday_policy) }
      context 'and the period is 1 day long' do
        before do
          time_off.update!(start_time: Date.new(2016,3,25), end_time: Date.new(2016,3,25) + 8.hours)
        end
        it { expect(subject).to eq 0 }
      end
      context 'and the period is longer than one day day long' do
        context 'and the holiday is in the first day of the time off' do
          before do
            time_off.update!(start_time: Date.new(2016,3,25), end_time: Date.new(2016,3,30))
          end
          it { expect(subject).to eq 60 }
        end
        context 'and the holiday is in the last day of the time off' do
          before do
            time_off.update!(start_time: Date.new(2016,3,21), end_time: Date.new(2016,3,25))
          end
          it { expect(subject).to eq 60 }
        end
        context 'and the holiday is in the middle of the time off ' do
          before do
            time_off.update!(start_time: Date.new(2016,3,24), end_time: Date.new(2016,3,26))
          end
          it { expect(subject).to eq 0 }
        end
      end
    end
  end

  context 'when employee does not have policy' do
    it { expect(subject).to eq 0 }
  end

  context 'when employee does not have time entries in policy' do
    it { expect(subject).to eq 0 }
  end
end
