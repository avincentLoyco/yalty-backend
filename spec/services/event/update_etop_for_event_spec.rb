require 'rails_helper'

RSpec.describe UpdateEtopForEvent do
  include_context 'shared_context_account_helper'

  # ACTIONS
  before(:each) do
    event.employee_attribute_versions << occupation_rate_attribute
    event.employee_time_off_policies << employee_time_off_policy
  end

  # BOILERPLATE
  let!(:effective_at) { Date.new(2017, 5, 1) }
  let!(:old_effective_at) { Date.new(2017, 4, 1) }
  let(:event_type) { 'hired' }
  let(:event) do
    create(:employee_event,
      effective_at: effective_at,
      event_type: event_type)
  end
  let(:employee) { event.employee }
  let!(:vacation_category) do
    create(:time_off_category, account: employee.account, name: 'vacation')
  end
  let(:employee_id) { employee.id }
  let(:time_off_policy_amount) { 20 }
  let(:occupation_rate_value) { 0.8 }
  let(:occupation_rate_definition) do
    create(:employee_attribute_definition,
      name: 'occupation_rate',
      account: employee.account,
      attribute_type: Attribute::Number.attribute_type,
      validation: { range: [0, 1] })
  end
  let(:occupation_rate_attribute) do
    create(:employee_attribute,
      event: event,
      employee: employee,
      attribute_definition: occupation_rate_definition,
      value: occupation_rate_value)
  end
  let!(:time_off_policy) do
    create(:time_off_policy,
      time_off_category_id: vacation_category.id,
      start_month: 1,
      start_day: 1,
      end_day: nil,
      end_month: nil,
      amount: 20 * 1440)
  end
  let!(:employee_time_off_policy) do
    create(:employee_time_off_policy, :with_employee_balance,
      employee: employee,
      time_off_policy: time_off_policy,
      effective_at: effective_at,
      occupation_rate: 0.8)
  end

  # SERVICE CALL
  subject { UpdateEtopForEvent.new(event.id, time_off_policy_amount, old_effective_at).call }

  # SHARED CASES
  shared_examples 'etops count did not change' do
    it do
      expect { subject }.not_to change(EmployeeTimeOffPolicy.where(employee_id: employee_id),
        :count)
    end
    it { expect { subject }.not_to change(event.employee_time_off_policies, :count) }
  end

  shared_examples 'etop occupation rate has changed' do
    it do
      expect { subject }.to change{EmployeeTimeOffPolicy.where(employee_id: employee_id).last
        .occupation_rate}.from(0.8).to(0.5)
    end
  end

  shared_examples 'time off policy amount has changed' do
    it do
      expect { subject }.to change{EmployeeTimeOffPolicy.where(employee_id: employee_id).last
        .time_off_policy.amount}.from(28800).to(14400)
    end
  end

  # TESTS
  context 'when updating hired event' do
    context 'and effective_at has changed' do
      it_behaves_like 'etops count did not change'
    end

    context 'and occupation rate has changed' do
      let(:occupation_rate_value) { 0.5 }
      it_behaves_like 'etops count did not change'
      it_behaves_like 'etop occupation rate has changed'
    end

    context 'and time off policy amount changed' do
      let(:time_off_policy_amount) { 10 }
      it_behaves_like 'etops count did not change'
      it_behaves_like 'time off policy amount has changed'
    end
  end

  context 'when updating work contract event' do
    let(:event_type) { 'work_contract' }

    context 'and effective_at has changed' do
      it_behaves_like 'etops count did not change'
    end

    context 'and occupation rate has changed' do
      let(:occupation_rate_value) { 0.5 }
      it_behaves_like 'etops count did not change'
      it_behaves_like 'etop occupation rate has changed'
    end

    context 'and time off policy amount changed' do
      let(:time_off_policy_amount) { 10 }
      it_behaves_like 'etops count did not change'
      it_behaves_like 'time off policy amount has changed'
    end
  end
end
