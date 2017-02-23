require 'rails_helper'

RSpec.describe CreateAdditionsAndRemovals do
  include_context 'shared_context_timecop_helper'

  let!(:account)  { create(:account) }
  let!(:employee) { create(:employee, account: account) }
  let!(:category) { create(:time_off_category, account: account) }
  let!(:policy) do
    create(:time_off_policy, :with_end_date, time_off_category: category, amount: 100)
  end
  let!(:etop) do
    create(:employee_time_off_policy, time_off_category: category, effective_at: Time.zone.now,
      time_off_policy: policy, employee: employee)
  end
  let!(:create_etop_balance_assignation) do
    create(:employee_balance_manual, :addition, employee: employee, time_off_category: category,
      effective_at: etop.effective_at + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
      validity_date: '2017-04-01'.to_date + Employee::Balance::REMOVAL_OFFSET)
  end
  let!(:create_etop_balance_removal) do
    create(:employee_balance_manual, employee: employee, time_off_category: category,
      effective_at: '2017-04-01'.to_date + Employee::Balance::REMOVAL_OFFSET,
      validity_date: nil)
  end

  subject(:execute_job) { CreateAdditionsAndRemovals.perform_now }

  context 'no other etops in category' do
    context 'there are no balances in periods yet' do
      it { expect { execute_job }.to change(Employee::Balance, :count).by(6) }
    end

    context 'there are already balances in upcoming period' do
      before do
        CreateAdditionsAndRemovals.perform_now
        Timecop.freeze(2017, 1, 1, 0, 0)
      end

      after { Timecop.freeze(2016, 1, 1, 0, 0) }

      it { expect { execute_job }.to change(Employee::Balance, :count).by(3) }
    end
  end

  context 'there is etop before active one' do
    let!(:previous_policy) do
      create(:time_off_policy, :with_end_date, time_off_category: category, amount: 500)
    end
    let!(:previous_etop) do
      create(:employee_time_off_policy, time_off_category: category, effective_at: 1.month.ago,
        time_off_policy: previous_policy, employee: employee)
    end

    before { execute_job }

    it { expect(Employee::Balance.count).to eq(8) }
    it { expect(Employee::Balance.additions.last.resource_amount).to eq(policy.amount) }
  end

  context 'there is etop after active one' do
    let!(:next_policy) do
      create(:time_off_policy, :with_end_date, time_off_category: category, amount: 500)
    end
    let!(:next_etop) do
      create(:employee_time_off_policy, :with_employee_balance, time_off_category: category,
        effective_at: 1.year.from_now + 5.days, time_off_policy: next_policy, employee: employee)
    end

    before { execute_job }

    it { expect(Employee::Balance.count).to eq(9) }
  end

  context 'there is etop after active one' do
    let!(:existing_balance) do
      create(:employee_balance_manual, :addition, employee: employee, time_off_category: category,
        effective_at: '2017-01-01'.to_date + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
        validity_date: '2018-04-01'.to_date + Employee::Balance::REMOVAL_OFFSET,
        created_at: 5.days.from_now, updated_at: 5.days.from_now)
    end

    it { expect { execute_job }.to change(Employee::Balance, :count).by(5) }
    it { expect { execute_job }.to_not change(existing_balance, :updated_at) }
  end

  context 'when employee has contract end date' do
    before do
      Timecop.freeze(2017, 1, 1, 0, 0)
      create(:employee_event,
        event_type: 'contract_end', effective_at: reset_etop_effective_at - 1.day,
        employee: employee)
    end

    let(:reset_policy) { create(:time_off_policy, :reset, time_off_category: category) }
    let!(:reset_etop) do
      create(:employee_time_off_policy,
        employee: employee, time_off_policy: reset_policy, effective_at: reset_etop_effective_at)
    end

    context 'and reset policy is assigned in the future' do
      let(:reset_etop_effective_at) { 1.year.since }

      it { expect { subject }.to_not change { Employee::Balance.count } }
      it { expect { subject }.to_not raise_error }
    end

    context 'and reset policy is assigned since today' do
      let(:reset_etop_effective_at) { Date.today }

      it { expect { execute_job }.to_not change { Employee::Balance.count } }
    end

    context 'and reset policy was assigned in the past' do
      let(:reset_etop_effective_at) { 1.year.ago + 1.week }

      context 'and employee is rehired' do
        # TODO
         xit { }
      end

      context 'and employee is not rehired' do
        it { expect { execute_job }.to_not change { Employee::Balance.count } }
      end
    end
  end

  context 'when etop time off policy has start day and month is not today' do
    context 'when start day is different' do
      before { policy.update!(start_day: 10) }

      it { expect { execute_job }.to_not change { Employee::Balance.count } }
    end

    context 'when start month is different' do
      before { policy.update!(start_month: 2) }

      it { expect { execute_job }.to_not change { Employee::Balance.count } }
    end
  end
end
