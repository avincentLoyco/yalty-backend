require 'rails_helper'

RSpec.describe HandleEppForEvent do
  let(:employee)           { hired.employee }
  let(:effective_at)       { Date.new(2015, 4, 21) }
  let(:occupation_rate)    { 0.5 }
  let(:event)              { hired }
  let(:presence_policy_id) { presence_policy.id }

  let!(:hired) { create(:employee_event, effective_at: effective_at, event_type: 'hired') }

  let!(:presence_policy) do
    create(:presence_policy, :with_time_entries, account: employee.account, occupation_rate: 0.5)
  end
  let!(:second_presence_policy) do
    create(:presence_policy, :with_time_entries,
      account: employee.account,
      occupation_rate: 0.8,
      number_of_days: 3,
      working_days: [1, 2, 4])
  end
  let!(:third_presence_policy) do
    create(:presence_policy, :with_time_entries,
      account: employee.account,
      occupation_rate: 0.9,
      number_of_days: 4,
      working_days: [1, 3, 5])
  end

  let!(:occupation_rate_definition) do
    create(:employee_attribute_definition,
      name: 'occupation_rate',
      account: employee.account,
      attribute_type: Attribute::Number.attribute_type,
      validation: { range: [0, 1] })
  end
  let!(:occupation_rate_version) do
    create(:employee_attribute,
      event: hired,
      employee: employee,
      attribute_definition: occupation_rate_definition,
      value: occupation_rate)
  end

  shared_examples 'Create EPP and assign it to event' do |params|
    it { expect { subject }.to change { EmployeePresencePolicy.count }.to(params[:epp_count]) }
    it { expect { subject }.to change { EmployeePresencePolicy.count }.by(1) }
    context 'created ETOP is assigned to event' do
      before { subject }
      it { expect(EmployeePresencePolicy.find_by(employee_event_id: event.id).present?).to be(true) }
    end
  end

  subject { described_class.new(event.id, presence_policy_id).call }

  context 'for hired event' do
    context 'without existing Employee Time Off Policy' do
      context 'when event OR is the same as PresencePolicy OR' do
        it_behaves_like 'Create EPP and assign it to event', epp_count: 1
      end

      context 'when event OR is different than PresencePolicy OR' do
        let(:occupation_rate) { 1.0 }
        it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
      end
    end

    context 'with existing Employee Time Off Policy' do
      let!(:etop) do
        create(:employee_time_off_policy, :with_employee_balance,
          employee: employee,
          effective_at: effective_at)
      end
      it_behaves_like 'Create EPP and assign it to event', epp_count: 1
    end
  end

  context 'for work contract event' do
    let(:event_type) { 'work_contract' }
    let(:work_contract) do
      create(:employee_event,
        employee: employee,
        effective_at: effective_at + 7.days,
        event_type: 'work_contract')
    end
    let!(:occupation_rate_version) do
      create(:employee_attribute,
        event: work_contract,
        employee: employee,
        attribute_definition: occupation_rate_definition,
        value: occupation_rate)
    end
    let!(:hired_epp) do
      create(:employee_presence_policy, :with_time_entries,
        employee: employee,
        presence_policy: presence_policy,
        effective_at: effective_at)
    end
    let(:presence_policy_id) { presence_policy.id }
    let(:event) { work_contract }

    before do
      employee.events << work_contract
    end

    context 'with previous EPP assigned' do
      context 'when both EPPs are the same' do
        it_behaves_like 'Create EPP and assign it to event', epp_count: 2
      end

      context 'when new EPP is different' do
        let(:occupation_rate) { 0.8 }
        let(:presence_policy_id) { second_presence_policy.id }

        it_behaves_like 'Create EPP and assign it to event', epp_count: 2
      end
    end

    context 'with previous and next EPP assigned' do
      let!(:next_epp) do
        create(:employee_presence_policy, :with_time_entries,
          employee: employee,
          presence_policy: presence_policy,
          effective_at: effective_at + 21.days,
          order_of_start_day: 2)
      end

      context 'when next EPP is same as previous' do
        context 'when all EPP are same' do
          it_behaves_like 'Create EPP and assign it to event', epp_count: 3
        end

        context 'when new EPP is different than previous and next one' do
          let(:occupation_rate)    { 0.8 }
          let(:presence_policy_id) { second_presence_policy.id }

          it_behaves_like 'Create EPP and assign it to event', epp_count: 3
        end
      end

      context 'when all EPP are different' do
        let!(:next_epp) do
          create(:employee_presence_policy, :with_time_entries,
            employee: employee,
            presence_policy: third_presence_policy,
            effective_at: effective_at + 21.days,
            order_of_start_day: 2)
        end
        let(:occupation_rate)    { 0.8 }
        let(:presence_policy_id) { second_presence_policy.id }

        it_behaves_like 'Create EPP and assign it to event', epp_count: 3
      end

      context 'when new Work Contract overwrites next one' do
        let!(:work_contract_event) do
          create(:employee_event,
            employee: employee,
            effective_at: effective_at + 7.days,
            event_type: 'work_contract')
        end
        let!(:same_date_etop) do
          create(:employee_presence_policy, :with_time_entries,
            employee: employee,
            presence_policy: third_presence_policy,
            effective_at: effective_at + 7.days,
            order_of_start_day: 2)
        end
        it { expect { subject }.not_to change { EmployeePresencePolicy.count } }

        context 'created ETOP is assigned to event' do
          before { subject }
          it do
            expect(EmployeePresencePolicy.find_by(employee_event_id: event.id).present?).to be(true)
          end
        end
      end
    end
  end
end
