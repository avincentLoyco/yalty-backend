require 'rails_helper'

RSpec.describe CalculateTimeOffBalance, type: :service do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  subject { CalculateTimeOffBalance.new(time_off).call }

  let(:policy) { create(:presence_policy) }
  let(:employee) do
    create(:employee, :with_time_off_policy, :with_presence_policy,
      presence_policy: policy
    )
  end
  let(:category) { employee.employee_time_off_policies.first.time_off_policy.time_off_category }
  let(:time_off) do
    create(:time_off, :without_balance,
      employee: employee, time_off_category: category, start_time: Date.today + 2.days,
      end_time: Date.today + 8.days
    )
  end

  context 'when the time off is long' do
    let(:time_off) do
      create(:time_off,
        employee: employee, time_off_category: category, start_time:  Date.new(2016,6,12),
        end_time:  Date.new(2016,6,25)+ 20.hours
      )
    end
    let(:presence_days) do
      [1,2,3,4,7].map do |i|
        create(:presence_day, order: i, presence_policy: policy)
      end
    end
    let!(:time_entries) do
      presence_days.map do |presence_day|
        create(:time_entry, presence_day: presence_day, start_time: '8:00', end_time: '9:00')
        create(:time_entry, presence_day: presence_day, start_time: '14:00', end_time: '15:00')
      end
    end

    context "and starts on a monday" do
      let(:time_off) do
        create(:time_off,
          employee: employee, time_off_category: category, start_time:  Date.new(2016,6,5),
          end_time:  Date.new(2016,6,14)+ 20.hours
        )
      end
      it { expect(subject).to eq 960 }
    end

    context "and starts on a sunday" do
      let(:time_off) do
        create(:time_off,
          employee: employee, time_off_category: category, start_time:  Date.new(2016,6,8),
          end_time:  Date.new(2016,6,15)+ 20.hours
        )
      end
      it { expect(subject).to eq 720 }
    end

    context "when it begins and ends on the same weekday" do
      let(:time_off) do
        create(:time_off,
          employee: employee, time_off_category: category, start_time:  Date.new(2016,6,6),
          end_time:  Date.new(2016,6,15)+ 20.hours
        )
      end
      it { expect(subject).to eq 960 }
    end

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

    context 'when time off period is 2 days long' do
      before do
        time_off.update!(start_time: Date.today - 1.day + 23.hours , end_time: Date.today + 11.hour)
        employee.employee_working_places.first.update!(effective_at: Time.now - 2.years)
      end

      it { expect(subject).to eq 300 }
    end

    context 'when time off shorter than one week' do
      it { expect(subject).to eq 600 }
    end

    context 'when time off longer than one week' do
      before { time_off.update!(end_time: Date.today + 17.days) }
      it { expect(subject).to eq 1200 }
    end

    context 'and there is more than one presence policy involved' do
      before { time_off.update!(start_time: Date.today, end_time: Date.today + 8.days) }

      let!(:second_epp) { create(:employee_presence_policy, employee: employee, effective_at: Date.today + 5.days) }
      let!(:second_policy) { second_epp.presence_policy }
      let(:third_day) { create(:presence_day, order: 3, presence_policy: second_policy) }
      let(:fourth_day) { create(:presence_day, order: 4, presence_policy: second_policy) }
      let!(:fourth_entry) do
        create(:time_entry, presence_day: third_day, start_time: '16:00', end_time: '17:15')
      end
      let!(:fifth_entry) do
        create(:time_entry, presence_day: fourth_day, start_time: '15:30', end_time: '17:00')
      end

      it { expect(subject).to eq 765 }

      context " and the time off is 2 days long" do
        before do
          second_epp.update(effective_at: Date.today + 1)
          third_day.update!(order: 6)
          time_off.update!(start_time: Date.today, end_time: Date.today + 2.day)
        end

        it { expect(subject).to eq 615 }
      end

      context "and the time off is 3 days long with 3 policies involved" do
        let!(:third_epp) { create(:employee_presence_policy, employee: employee, effective_at: Date.today + 2.days) }
        let(:third_policy) { third_epp.presence_policy }
        let(:fifth_day) { create(:presence_day, order: 7, presence_policy: third_policy) }
        let!(:sixth_enty) do
          create(:time_entry, presence_day: fifth_day, start_time: '15:00', end_time: '15:07')
        end
        before do
          second_epp.update(effective_at: Date.today + 1)
          third_day.update!(order: 6)
          time_off.update!(start_time: Date.today, end_time: Date.today + 3.day)
        end
          it { expect(subject).to eq 622   }
      end
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
      before { employee.working_places.first.update!(holiday_policy: holiday_policy) }
      context 'and the period is 1 day long' do
        before do
          time_off.update!(start_time: Date.new(2016,3,25), end_time: Date.new(2016,3,25) + 8.hours)
        end
        it { expect(subject).to eq 0 }
      end

      context 'and there are multiple working places with different holiday policies' do
        let(:second_day) { create(:presence_day, order: 4, presence_policy: policy) }
        let(:first_day) { create(:presence_day, order: 7, presence_policy: policy) }
        let(:holiday_policy) { create(:holiday_policy, country: 'ch', region: 'ai') }
        let(:holiday_policy_ow) { create(:holiday_policy, country: 'ch', region: 'ow') }
        let!(:second_ewp) do
          create(:employee_working_place,
            employee: employee,
            effective_at: Date.new(2016,9,23)
            )
        end
        let!(:third_ewp) do
          create(:employee_working_place,
            employee: employee,
            effective_at: Date.new(2016,9,26)
            )
        end
        let(:second_working_place) { second_ewp.working_place }

        before do
          second_ewp.working_place.update!(holiday_policy: holiday_policy_ow)
          time_off.update!(start_time: Date.new(2016,9,21), end_time: Date.new(2016,9,28))
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
