require 'rails_helper'

RSpec.describe EmployeePolicyPeriod do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  let(:account) { create(:account) }
  let(:category) { create(:time_off_category, account: account) }
  let(:policy) { create(:time_off_policy, time_off_category: category, start_month: 4) }
  let(:previous_policy) { create(:time_off_policy, time_off_category: category) }
  let(:employee) { create(:employee, account: account) }
  subject { EmployeePolicyPeriod.new(employee, category.id) }

  context 'when employee time off policy is a reset policy' do
    before do
      create(:employee_event, employee: employee, event_type: 'contract_end',
        effective_at: effective_at - 1.day)
      if effective_at < second_date
        create(:employee_event, employee: employee, event_type: 'hired', effective_at: second_date)
      end
    end
    let!(:etops) do
      [first_date, second_date].map do |date|
        create(:employee_time_off_policy,
          employee: employee, effective_at: date,
          time_off_policy: create(:time_off_policy, time_off_category: category))
      end
    end
    let!(:reset_etop) do
      create(:employee_time_off_policy,
        employee: employee, effective_at: effective_at,
        time_off_policy: create(:time_off_policy, :reset, time_off_category: category))
    end

    context 'when reset etop is in previous period' do
      let(:first_date) { 10.months.since }
      let(:second_date) { Date.today }
      let(:effective_at) { 9.months.ago }

      it { expect(subject.current_start_date).to eq '1/1/2016'.to_date }
      it { expect(subject.next_start_date).to eq '1/1/2017'.to_date }
      it { expect(subject.future_start_date).to eq '1/1/2018'.to_date }
      it { expect(subject.previous_start_date).to eq effective_at }
      it do
        expect(subject.previous_policy_period).to include(
          ('1.4.2015'.to_date)..('1.1.2016'.to_date)
        )
      end
      it do
        expect(subject.current_policy_period).to include(
          ('1.1.2016'.to_date)..('1.1.2017'.to_date)
        )
      end
      it do
        expect(subject.future_policy_period).to include(
          ('1.1.2017'.to_date)..('1.1.2018'.to_date)
        )
      end
    end

    context 'when reset etop is in current period' do
      let(:effective_at) { Date.today }
      let(:first_date) { 5.months.ago }
      let(:second_date) { 13.months.since }

      it { expect(subject.current_start_date).to eq '1/1/2016'.to_date }
      it { expect(subject.next_start_date).to eq '1/2/2017'.to_date }
      it { expect(subject.future_start_date).to eq '1/1/2018'.to_date }
      it { expect(subject.previous_start_date).to eq '1/8/2015'.to_date }

      it do
        expect(subject.previous_policy_period).to include(
          ('1.8.2015'.to_date)..('1.1.2016'.to_date)
        )
      end
      it do
        expect(subject.current_policy_period).to include(
          ('1.1.2016'.to_date)..('1.2.2017'.to_date)
        )
      end
      it do
        expect(subject.future_policy_period).to include(
          ('1.2.2017'.to_date)..('1.1.2018'.to_date)
        )
      end
    end

    context 'when reset etop is in future period' do
      let(:effective_at) { 5.months.since }
      let(:first_date) { Date.today }
      let(:second_date) {  5.months.ago }

      it { expect(subject.current_start_date).to eq '1/1/2016'.to_date }
      it { expect(subject.next_start_date).to eq '1/6/2016'.to_date }
      it { expect(subject.future_start_date).to eq nil }
      it { expect(subject.previous_start_date).to eq '1/8/2015'.to_date }

      it do
        expect(subject.previous_policy_period).to include(
          ('1.8.2015'.to_date)..('1.1.2016'.to_date)
        )
      end
      it do
        expect(subject.current_policy_period).to include(
          ('1.1.2016'.to_date)..('1.6.2016'.to_date)
        )
      end
      it { expect(subject.future_policy_period).to eq(nil) }
    end
  end

  context 'when previous policy not present' do
    let!(:current_policy) do
      create(:employee_time_off_policy,
        employee: employee, time_off_policy: previous_policy, effective_at: effective_at
      )
    end

    context 'when employee does not have previous policy' do
      let(:effective_at) { Date.today - 2.years }

      it { expect(subject.current_start_date).to eq '1/1/2016'.to_date }
      it { expect(subject.next_start_date).to eq '1/1/2017'.to_date }
      it { expect(subject.future_start_date).to eq '1/1/2018'.to_date }
      it { expect(subject.previous_start_date).to eq '1/1/2015'.to_date }
      it { expect(subject.previous_policy_period)
        .to include(('1.1.2015'.to_date)..('1.1.2016'.to_date)) }
      it { expect(subject.current_policy_period)
        .to include(('1.1.2016'.to_date)..('1.1.2017'.to_date)) }
      it { expect(subject.future_policy_period)
        .to include(('1.1.2017'.to_date)..('1.1.2018'.to_date)) }
    end
  end

  context 'when previous policy present' do
    let(:second_effective_at) { Date.today - 2.years }
    let!(:second_policy) do
      create(:employee_time_off_policy,
        employee: employee, time_off_policy: policy, effective_at: second_effective_at
      )
    end
    let!(:current_policy) do
      create(:employee_time_off_policy,
        employee: employee, time_off_policy: previous_policy, effective_at: effective_at
      )
    end

    context '#current_start_date' do
      subject { EmployeePolicyPeriod.new(employee, category.id).current_start_date }

      context 'but already new came in' do
        let(:effective_at) { Date.today - 4.months }

        it { expect(subject).to eq '1/1/2016'.to_date }
      end

      context 'and new has start date in future' do
        let(:effective_at) { Date.today + 1.month }

        it { expect(subject).to eq '1/4/2015'.to_date }
      end
    end

    context '#next_start_date' do
      subject { EmployeePolicyPeriod.new(employee, category.id).next_start_date }

      context 'when there is new policy in the future' do
        let(:effective_at) { Date.today + 2.months }

        it { expect(subject).to eq '1/4/2016'.to_date }
      end

      context 'when policy after current policy end date' do
        before { policy.update!(years_to_effect: 8) }
        let(:effective_at) { Date.today + 1.year }

        it { expect(subject).to eq '1/1/2017'.to_date }
      end
    end

    context '#future_start_date' do
      let(:effective_at) { Date.today + 2.months }

      subject { EmployeePolicyPeriod.new(employee, category.id).future_start_date }

      context 'when there is future time off policy' do
        let(:future_policy) do
          create(:time_off_policy, time_off_category: category, start_month: 9)
        end
        let!(:future_related_policy) do
          create(:employee_time_off_policy,
            employee: employee, time_off_policy: future_policy, effective_at: Date.today + 6.months
          )
        end

        it { expect(subject).to eq '1/9/2016'.to_date }
      end

      context 'when there is only next time off policy' do
        it { expect(subject).to eq '1/4/2017'.to_date }
      end
    end

    context '#current_policy_period' do
      subject { EmployeePolicyPeriod.new(employee, category.id).current_policy_period }

      context 'other policy end date' do
        let(:effective_at) { Date.today + 1.month }

        it { expect(subject).to include(('1.1.2016'.to_date)..('1.4.2016'.to_date)) }
      end
    end

    context '#previous_start_date' do
      subject { EmployeePolicyPeriod.new(employee, category.id).previous_start_date }

      context 'other policy period' do
        let(:effective_at) { Date.today - 4.months }

        it { expect(subject).to eq '1/4/2015'.to_date }
      end
    end

    context '#previous_policy_period' do
      subject { EmployeePolicyPeriod.new(employee, category.id).previous_policy_period }

      context 'other policy period' do
        let(:effective_at) { Date.today - 1.year }

        it { expect(subject).to include(('1.4.2015'.to_date)..('1.1.2016'.to_date)) }
      end
    end
  end
end
