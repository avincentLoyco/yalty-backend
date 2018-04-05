require "rails_helper"

RSpec.describe Events::WorkContract::Update do
  include_context "event update context"

  it_behaves_like "event update example"

  shared_examples "calls ContractEnd::Update" do
    it "calls ContractEnd::Update service" do
      subject
      expect(update_etop_for_event).to have_received(:new)
        .with(
          event.id,
          time_off_policy_amount,
          event.effective_at
      )
      expect(update_etop_for_event_instance).to have_received(:call)
    end
  end

  before do
    use_case.etop_updater = update_etop_for_event
    Account.current = account

    allow(event_updater_instance).to receive(:call).and_return(event)
    allow(update_etop_for_event).to receive(:new).and_return(update_etop_for_event_instance)
    allow(update_etop_for_event_instance).to receive(:call)

    allow(EmployeePolicy::Presence::Update).to receive(:call)
    allow(EmployeePolicy::Presence::Destroy).to receive(:call)
    allow(EmployeePolicy::Presence::Create).to receive(:call)

    allow(event).to receive(:attribute_value).with("occupation_rate").and_return("0.5")
    allow(event).to receive(:employee_presence_policy).and_return(employee_presence_policy)
  end

  let(:update_etop_for_event)          { class_double("UpdateEtopForEvent") }
  let(:update_etop_for_event_instance) { instance_double("UpdateEtopForEvent") }

  let(:account)  { create(:account) }
  let(:employee) { create(:employee, account: account) }

  let(:effective_at)  { employee.events.order(:effective_at).first.effective_at + 10.days }
  let(:changed_event) { event.dup.tap{ |event| event.effective_at -= 5.day } }

  let(:default_presence_policy) { employee.account.presence_policies.full_time }
  let(:presence_policy_id)      { default_presence_policy.id }
  let(:time_off_policy_amount)  { 20 }

  let(:event) do
    build_stubbed(
      :employee_event,
      event_type: "work_contract",
      employee: employee,
      effective_at: effective_at
    )
  end

  let(:employee_presence_policy) do
    build_stubbed(
      :employee_presence_policy,
      employee: employee,
      effective_at: effective_at,
      presence_policy: default_presence_policy
    )
  end

  let(:params) do
    {
      employee_attributes: employee_attributes,
      time_off_policy_amount: time_off_policy_amount,
      presence_policy_id: presence_policy_id,
      effective_at: changed_event.effective_at
    }
  end

  context "when presence policy did not change" do
    it "updates employee presence policy" do
      subject
      expect(EmployeePolicy::Presence::Update).to have_received(:call)
    end

    it_behaves_like "calls ContractEnd::Update"
  end

  context "when presence policy did change" do
    let(:presence_policy_id) { "different_id" }

    it "updates employee presence policy" do
      subject
      expect(EmployeePolicy::Presence::Destroy).to have_received(:call)
      expect(EmployeePolicy::Presence::Create).to have_received(:call)
    end

    it_behaves_like "calls ContractEnd::Update"
  end

  context "when invalid params" do
    context "without time off policy amount" do
      let(:time_off_policy_amount) { nil }

      it { expect{ subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
    end

    context "without presence policy" do
      let(:presence_policy_id) { nil }

      it { expect{ subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
    end

    context "without matching occupation rate" do
      before { allow(event).to receive(:attribute_value).with("occupation_rate").and_return("0.8") }

      it { expect{ subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
    end
  end
end
