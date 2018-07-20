require "rails_helper"

RSpec.describe CalculateTimeOffBalance, type: :service do
  include_context "shared_context_account_helper"
  include_context "shared_context_timecop_helper"

  subject { CalculateTimeOffBalance.new(time_off).call }

  let(:policy)     { create(:presence_policy, :with_presence_day) }
  let(:category)   { employee.employee_time_off_policies.first.time_off_policy.time_off_category }
  let(:start_time) { 2.days.since }
  let(:end_time)   { 8.days.since }
  let!(:employee) do
    create(:employee, :with_time_off_policy, :with_presence_policy,
      presence_policy: policy
    )
  end
  let(:time_off) do
    create(:time_off,
      employee: employee, time_off_category: category, start_time: start_time, end_time: end_time
    )
  end

  context "when presence policy is 7-days long" do
    before do
      employee.employee_presence_policies.first.update!(effective_at: Date.new(2015, 12, 28))
      policy.presence_days.map(&:destroy!)
    end

    context "when the time off is long" do
      let!(:presence_days) do
        [1, 2, 3, 4, 7].map do |i|
          create(:presence_day, order: i, presence_policy: policy)
        end
      end
      let!(:time_entries) do
        presence_days.map do |presence_day|
          create(:time_entry, presence_day: presence_day, start_time: "8:00", end_time: "9:00")
          create(:time_entry, presence_day: presence_day, start_time: "14:00", end_time: "15:00")
        end
      end

      context "and starts on a monday" do
        let(:start_time) { Date.new(2016, 6, 5) }
        let(:end_time)   { Date.new(2016, 6, 14) + 20.hours }

        it { expect(subject).to eq 960 }
      end

      context "and starts on a sunday" do
        let(:start_time) { Date.new(2016, 6, 8) }
        let(:end_time)   { Date.new(2016, 6, 15) + 20.hours }

        it { expect(subject).to eq 720 }
      end

      context "when it begins and ends on the same weekday" do
        let(:start_time) { Date.new(2016, 6, 6) }
        let(:end_time)   { Date.new(2016, 6, 15) + 20.hours }

        it { expect(subject).to eq 960 }
      end
    end
  end

  context "when presence policy is 4-days long" do
    before { policy.presence_days.map(&:destroy!) }
    let(:end_time) { Date.today + 8.days + 20.hours }
    let(:presence_days) do
      [1, 2, 3, 4].map do |order|
        create(:presence_day, order: order, presence_policy: policy)
      end
    end
    let!(:time_entries) do
      [presence_days.first, presence_days.second, presence_days.last].map do |day|
        create(:time_entry, presence_day: day, start_time: "8:00", end_time: "9:00")
        create(:time_entry, presence_day: day, start_time: "18:00", end_time: "21:00")
      end
    end

    context "and time off starts in monday" do
      it { expect(subject).to eq 1140 }
    end

    context "and time off starts in saturday" do
      let(:start_time) { Date.new(2016, 1, 2) }
      let(:end_time)   { Date.new(2016, 1, 8) + 20.hours }

      it { expect(subject).to eq 1140 }
    end

    context "and time off is longer than two weeks" do
      let(:start_time) { Date.new(2016, 1, 2) }
      let(:end_time)   { Date.new(2016, 1, 20) + 20.hours }

      it { expect(subject).to eq 3300 }
    end
  end

  context "when presence policy is 1-day long" do
    before { policy.presence_days.map(&:destroy!) }
    let(:end_time) { Date.new(2016, 1, 9) + 20.hours }
    let(:presence_day) { create(:presence_day, order: 1, presence_policy: policy) }
    let!(:time_entry) do
      create(:time_entry, presence_day: presence_day, start_time: "19:00", end_time: "21:00")
    end

    it { expect(subject).to eq 780 }
  end

  context "when employee have time_entries in policy" do
    let(:first_day)     { create(:presence_day, order: 2, presence_policy: policy) }
    let(:second_day)    { create(:presence_day, order: 7, presence_policy: policy) }
    let!(:first_entry)  { create(:time_entry, presence_day: first_day) }
    let!(:second_entry) { create(:time_entry, presence_day: second_day) }
    let!(:third_entry) do
      create(:time_entry, presence_day: second_day, start_time: "6:00", end_time: "14:00")
    end

    context "when time off for few hours" do
      let(:start_time) { 6.days.since }
      let(:end_time)   { 6.days.since + 8.hours }

      it { expect(subject).to eq 120 }
    end

    context "when time off period is 2 days long" do
      before do
        employee.first_employee_event.update!(effective_at: Time.now - 2.years)
      end

      let(:start_time) { 5.days.since + 23.hours }
      let(:end_time)   { 6.days.since + 11.hours }

      it { expect(subject).to eq 300 }
    end

    context "when time off shorter or equal one week" do
      let(:start_time) { Date.today }
      let(:end_time)   { 7.days.since }

      it { expect(subject).to eq 600 }
    end

    context "when time off longer than one week" do
      let(:start_time) { Date.today }
      let(:end_time)   { 14.days.since }

      it { expect(subject).to eq 1200 }
    end

    context "when presence policy starts in the middle of time off" do
      before { employee.employee_presence_policies.first.update!(effective_at: 7.days.since) }
      let(:start_time) { Date.today }
      let(:end_time)   { 14.days.since }

      it { expect(subject).to eq 600 }
    end

    context "and there is more than one presence policy involved" do
      before { second_policy.presence_days.map(&:destroy!) }
      let(:start_time) { Date.today }
      let(:end_time)   { 8.days.since }
      let!(:second_epp) do
        create(:employee_presence_policy, employee: employee, effective_at: 5.days.since)
      end
      let!(:second_policy) { second_epp.presence_policy }

      let(:third_day)  { create(:presence_day, order: 3, presence_policy: second_policy) }
      let(:fourth_day) { create(:presence_day, order: 4, presence_policy: second_policy) }
      let!(:fourth_entry) do
        create(:time_entry, presence_day: third_day, start_time: "16:00", end_time: "17:15")
      end
      let!(:fifth_entry) do
        create(:time_entry, presence_day: fourth_day, start_time: "15:30", end_time: "17:00")
      end

      it { expect(subject).to eq 135 }

      context "and the time off is 2 days long" do
        before do
          second_epp.update(effective_at: 1.day.since)
          third_day.update!(order: 1)
          second_day.update!(order: 1)
        end

        let(:start_time) { Date.today }
        let(:end_time)   { 2.days.since }

        it { expect(subject).to eq 615 }
      end

      context "and the time off is 3 days long with 3 policies involved" do
        let(:start_time)   { Date.today }
        let(:end_time)     { 3.days.since }
        let(:third_policy) { third_epp.presence_policy }
        let(:fifth_day)    { create(:presence_day, order: 1, presence_policy: third_policy) }
        let(:third_epp) do
          create(:employee_presence_policy, employee: employee, effective_at: 2.days.since)
        end
        let!(:sixth_entry) do
          create(:time_entry, presence_day: fifth_day, start_time: "15:00", end_time: "15:07")
        end
        before do
          second_epp.update(effective_at: 1.day.since)
          third_day.update!(order: 1)
          second_day.update!(order: 1)
        end

        it { expect(subject).to eq 622 }
      end
    end

    context "time off start and ends in the middle of entries" do
      before { EmployeePresencePolicy.first.update!(order_of_start_day: 5) }
      let(:start_time) { 2.days.since + 7.hours }
      let(:end_time)   { 11.days.since + 16.hours + 30.minutes }

      it { expect(subject).to eq 1110 }
    end

    context "and when there are holidays in the time off period" do
      let(:holiday_policy) { create(:holiday_policy, country: "ch", region: "zh") }
      let!(:employee_working_place) do
        create(
          :employee_working_place,
          employee: employee,
          working_place: create(:working_place, holiday_policy: holiday_policy),
        )
      end

      context "and the period is 1 day long" do
        let(:start_time) { Date.new(2016, 3, 25) }
        let(:end_time)   { Date.new(2016, 3, 25) + 8.hours }

        it { expect(subject).to eq 0 }
      end

      context "and there are multiple working places with different holiday policies" do
        before { second_ewp.working_place.update!(holiday_policy: holiday_policy_ow) }

        let(:second_day)        { create(:presence_day, order: 4, presence_policy: policy) }
        let(:first_day)         { create(:presence_day, order: 7, presence_policy: policy) }
        let(:holiday_policy)    { create(:holiday_policy, country: "ch", region: "ai") }
        let(:holiday_policy_ow) { create(:holiday_policy, country: "ch", region: "ow") }
        let!(:second_ewp) do
          create(:employee_working_place,
            employee: employee,
            effective_at: Date.new(2016, 9, 23)
            )
        end
        let!(:third_ewp) do
          create(:employee_working_place,
            employee: employee,
            effective_at: Date.new(2016, 9, 26)
            )
        end
        let(:second_working_place) { second_ewp.working_place }
        let(:start_time) { Date.new(2016, 9, 21) }
        let(:end_time)   { Date.new(2016, 9, 28) }

        it { expect(subject).to eq 540 }
      end

      context "and the period is longer than one day day long" do
        before { EmployeePresencePolicy.first.update!(order_of_start_day: 5) }

        context "and the holiday is in the first day of the time off" do
          let(:start_time) { Date.new(2016, 3, 25) }
          let(:end_time)   { Date.new(2016, 3, 30) }

          it { expect(subject).to eq 600 }
        end
        context "and the holiday is in the last day of the time off" do
          let(:start_time) { Date.new(2016, 3, 21) }
          let(:end_time)   { Date.new(2016, 3, 25) }

          it { expect(subject).to eq 60 }
        end
        context "and the holiday is in the middle of the time off " do
          let(:start_time) { Date.new(2016, 3, 24) }
          let(:end_time)   { Date.new(2016, 3, 26) }

          it { expect(subject).to eq 0 }
        end
      end
    end
  end

  context "when employee does not have policy" do
    it { expect(subject).to eq 0 }
  end

  context "when employee does not have time entries in policy" do
    it { expect(subject).to eq 0 }
  end
end
