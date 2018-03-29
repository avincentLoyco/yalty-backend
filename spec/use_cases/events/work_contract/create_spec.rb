require "rails_helper"

RSpec.describe Events::WorkContract::Create do
  include_context "event create use case"

  let(:params) do
    {
      time_off_policy_amount: time_off_policy_amount,
      presence_policy_id: presence_policy_id,
      event_type: :hired,
      effective_at: effective_at,
      employee: {},
      employee_attributes: [
        {attribute_name: "firstname", value: "Walter"},
        {attribute_name: "lastname", value: "Smith"},
        {attribute_name: "occupation_rate", value: "0.8"},
      ]
    }
  end

  let(:effective_at) { Date.new(2105,02,02) }
  let(:time_off_policy_amount) { 30 }
  let(:presence_policy_id) { "fake_id" }
  let(:account) { create(:account) }

  before do
    Account.current = account
    use_case.event_creator = ::CreateEvent
  end

  context "with valid params" do
    before do
      create(
        :employee_attribute_definition,
        name: "occupation_rate",
        account: account,
        attribute_type: Attribute::Number.attribute_type,
        validation: { range: [0, 1] }
      )

      allow(EmployeePolicy::Presence::Create).to receive(:call).and_call_original
    end

    let(:presence_policy) do
      create(
        :presence_policy,
        :with_time_entries,
        account: account,
        occupation_rate: presence_policy_occupation_rate,
        standard_day_duration: day_duration,
        default_full_time: false
      )
    end

    let(:day_duration) { account.presence_policies.full_time.standard_day_duration }
    let(:presence_policy_occupation_rate) { 0.8 }
    let(:presence_policy_id) { presence_policy.id }

    it "returns result from event_creator" do
      expect(subject)
        .to have_attributes(
          effective_at: effective_at,
          event_type: "hired",
          active: true,
          employee_id: kind_of(String),
          attribute_values: {"firstname"=>"Walter", "lastname"=>"Smith", "occupation_rate"=>"0.8"},
        )
    end

    it "calls EmployeePolicy::Presence::Create service" do
      subject
      expect(EmployeePolicy::Presence::Create)
        .to have_received(:call)
        .with hash_including(event_id: subject.id, presence_policy_id: presence_policy_id)
    end

    context "CreateEtopForEvent" do
      before do
        use_case.etop_creator = create_etop_service
        allow(create_etop_service).to receive(:new).and_return(create_etop_instance)
        allow(create_etop_instance).to receive(:call)
      end

      let(:create_etop_service) { class_double("CreateEtopForEvent") }
      let(:create_etop_instance) { instance_double("CreateEtopForEvent") }
      let(:etop_amount) { day_duration * 30 }

      it "calls CreateEtopForEvent service" do
        subject
        expect(create_etop_service).to have_received(:new).with(subject.id, etop_amount)
        expect(create_etop_instance).to have_received(:call)
      end
    end

    context "when occupation rate is doesn't match" do
      let(:presence_policy_occupation_rate) { 0.9 }

      it "raises InvalidResourcesError" do
        expect{ subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError)
      end
    end
  end

  context "when params missing" do
    context "when time off policy amount is not present" do
      let(:time_off_policy_amount) { nil }

      it "raises InvalidResourcesError" do
        expect{ subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError)
      end
    end

    context "when presence policy is not present" do
      let(:presence_policy_id) { nil }

      it "raises InvalidResourcesError" do
        expect{ subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError)
      end
    end
  end
end
