require "rails_helper"

RSpec.describe Events::WorkContract::Create do
  subject do
    described_class
      .new(
        create_event_service: create_event_service_class_mock,
        create_etop_for_event_service: create_etop_for_event_service_class_mock,
        create_employee_presence_policy_service: create_employee_presence_policy_service_mock,
        assign_employee_to_all_tops: assign_employee_to_all_tops_mock,
        account_model: account_model_mock,
        invalid_resources_error: invalid_resources_error,
      )
      .call(params)
  end

  let(:create_event_service_class_mock) do
    class_double(CreateEvent, new: create_event_service_instance_mock)
  end
  let(:create_event_service_instance_mock) do
    instance_double(CreateEvent, call: event)
  end

  let(:create_etop_for_event_service_class_mock) do
    class_double(CreateEtopForEvent, new: create_etop_for_event_service_instance_mock)
  end
  let(:create_etop_for_event_service_instance_mock) do
    instance_double(CreateEtopForEvent, call: true)
  end

  let(:create_employee_presence_policy_service_mock) do
    class_double(EmployeePolicy::Presence::Create, call: true)
  end

  let(:assign_employee_to_all_tops_mock) do
    instance_double(Employees::AssignEmployeeToAllTops, call: true)
  end

  let(:account) { build(:account) }
  let(:account_model_mock) { class_double(Account, current: account) }

  let(:invalid_resources_error) { API::V1::Exceptions::InvalidResourcesError }


  let(:params) do
    {
      time_off_policy_amount: time_off_policy_amount,
      presence_policy_id: presence_policy_id,
      event_type: :hired,
      effective_at: effective_at,
      employee: {},
      employee_attributes: [
        { attribute_name: "firstname", value: "Walter" },
        { attribute_name: "lastname", value: "Smith" },
        { attribute_name: "occupation_rate", value: event_occupation_rate },
      ],
    }
  end

  let(:effective_at) { Date.new(2105,02,02) }
  let(:time_off_policy_amount) { 30 }
  let(:presence_policy_id) { "presence_policy_id" }
  let(:event_occupation_rate) { "0.8" }

  let(:event) { build(:employee_event, employee_presence_policy: employee_presence_policy) }
  let!(:employee_presence_policy) { build(:employee_presence_policy) }

  before do
    allow(account).to receive(:standard_day_duration).and_return(9600)
    Account.current = account
  end

  context "with valid params" do
    before do
      allow(create_employee_presence_policy_service_mock).to receive(:call).and_return(true)
      allow(event).to receive(:attribute_value).and_return(event_occupation_rate)
      employee_presence_policy.presence_policy.occupation_rate = presence_policy_occupation_rate
    end

    let(:day_duration) { account.standard_day_duration }
    let(:presence_policy_occupation_rate) { 0.8 }

    it "creates event" do
      expect(subject).to eq(event)

      expect(create_event_service_class_mock).to have_received(:new).with(
        params, params[:employee_attributes]
      )

      expect(create_event_service_instance_mock).to have_received(:call)
    end

    it "creates employee presence policy" do
      subject
      expect(create_employee_presence_policy_service_mock)
        .to have_received(:call)
        .with(event_id: event.id, presence_policy_id: presence_policy_id)
    end

    it "creates employee time off policy for event" do
      subject
      expect(create_etop_for_event_service_class_mock).to have_received(:new).with(
        event.id,
        time_off_policy_amount * account.standard_day_duration
      )

      expect(create_etop_for_event_service_instance_mock).to have_received(:call)
    end

    it "assigns employee to all time off policies" do
      subject
      expect(assign_employee_to_all_tops_mock).to have_received(:call).with(event.employee)
    end

    context "when occupation rate is doesn't match" do
      let(:presence_policy_occupation_rate) { 0.9 }

      it "raises InvalidResourcesError" do
        expect { subject }.to raise_error(invalid_resources_error)
      end
    end
  end

  context "when params missing" do
    context "when time off policy amount is not present" do
      let(:time_off_policy_amount) { nil }

      it "raises InvalidResourcesError" do
        expect { subject }.to raise_error(invalid_resources_error)
      end
    end

    context "when presence policy is not present" do
      let(:presence_policy_id) { nil }

      it "raises InvalidResourcesError" do
        expect { subject }.to raise_error(invalid_resources_error)
      end
    end
  end
end
