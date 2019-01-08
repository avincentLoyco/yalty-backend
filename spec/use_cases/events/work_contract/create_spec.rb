require "rails_helper"

RSpec.describe Events::WorkContract::Create do
  describe "#call" do
    include_context "event create use case"
    include_context "end of contract balance handler context"

    subject do
      described_class
        .new(
          create_event_service: create_event_service_class_mock,
          create_etop_for_event_service: create_etop_for_event_service_class_mock,
          create_employee_presence_policy_service: create_employee_presence_policy_service_mock,
          assign_employee_to_all_tops: assign_employee_to_all_tops_mock,
          account_model: account_model_mock,
          invalid_resources_error: invalid_resources_error,
          find_and_destroy_eoc_balance: find_and_destroy_eoc_balance_mock,
          create_eoc_balance: create_eoc_balance_mock,
          find_first_eoc_event_after: find_first_eoc_event_after_mock,
        )
        .call(params)
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
        employee: { id: event.employee.id },
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

      it_behaves_like "event create example"
      it_behaves_like "end of contract balance handler for an event"

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

      xit "assigns employee to all time off policies" do
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

  # NOTE: Integration tests start below

  context "integration tests" do

    subject { described_class.new.call(params) }

    let(:params) do
      {
        effective_at: effective_at,
        event_type: "work_contract",
        time_off_policy_amount: 30,
        employee: { id: employee.id, manager_id: nil },
        presence_policy_id: half_time_presence_policy.id,
        employee_attributes: [{ attribute_name: "occupation_rate", value: "0.5" }],
      }
    end

    let(:effective_at) { Date.new(2018, 11, 15) }
    let(:hired_date) { Date.new(2018, 11, 1)}
    let(:account) { create(:account) }
    let(:employee) { account.employees.first }
    let(:full_time_presence_policy) do
      create(:presence_policy, :with_presence_day, account: account, occupation_rate: 1.0)
    end
    let(:half_time_presence_policy) do
      create(:presence_policy, :with_presence_day, account: account, occupation_rate: 0.5)
    end
    let(:employee_presence_policy) do
      create(
        :employee_presence_policy,
        employee: employee,
        presence_policy: full_time_presence_policy,
        effective_at: employee.hired_date,
      )
    end
    let(:vacation_toc) { employee.account.time_off_categories.vacation.first }

    let(:occupation_rate_definition) do
      create(:employee_attribute_definition,
        account: account,
        name: "occupation_rate",
        attribute_type: "Number",
        validation: { range: [0, 1] })
    end

    before do
      Account.current = account

      create(:employee_attribute_definition,
        account: account,
        name: "personal_email",
        attribute_type: "String")

      create(:employee_attribute_definition,
        account: account,
        name: "professional_email",
        attribute_type: "String")

      create(:employee_attribute_definition,
        account: account,
        name: "occupation_rate",
        attribute_type: "Number",
        validation: { range: [0, 1] })

      # Hire employee
      described_class.new.call(
        {
          effective_at: hired_date,
          event_type: "hired",
          time_off_policy_amount: 30,
          employee: { manager_id: nil },
          presence_policy_id: full_time_presence_policy.id,
          employee_attributes: [
            { attribute_name: "firstname", value: "Grzegorz" },
            { attribute_name: "lastname", value: "Brzęczyszczykiewicz" },
            { attribute_name: "personal_email", value: nil },
            { attribute_name: "professional_email", value: nil },
            { attribute_name: "occupation_rate", value: "1" },
          ],
        }
      )
    end

    context "when there is no end of contract" do
      it do
        balances = employee.employee_balances.order(:effective_at)

        expect(balances[0]).to have_attributes(
          balance_type: "assignation",
          balance: 2407,
          resource_amount: 0,
          effective_at: within(10.seconds).of(hired_date.to_time(:utc))
        )
        expect(balances[1]).to have_attributes(
          balance_type: "end_of_period",
          balance: 2407,
          resource_amount: 0,
          effective_at: within(10.seconds).of(Date.new(2019,1,1).to_time(:utc))
        )

        subject
        balances.reload

        expect(balances[0]).to have_attributes(
          balance_type: "assignation",
          balance: 2407,
          resource_amount: 0,
          effective_at: within(10.seconds).of(hired_date.to_time(:utc))
        )
        expect(balances[1]).to have_attributes(
          balance_type: "assignation",
          balance: 1480,
          resource_amount: 0,
          effective_at: within(10.seconds).of(effective_at.to_time(:utc))
        )
        expect(balances[2]).to have_attributes(
          balance_type: "end_of_period",
          balance: 1480,
          resource_amount: 0,
          effective_at: within(10.seconds).of(Date.new(2019,1,1).to_time(:utc))
        )
      end
    end

    context "when there is end of contract" do
      include ActiveJob::TestHelper

      let(:hired_date) { Date.new(2018, 11, 1)}
      let(:contract_end_date) { Date.new(2018,12,1) }
      let(:effective_at) { Date.new(2018, 11, 15) }

      before do
        Events::ContractEnd::Create.new.call(
          {
            effective_at: contract_end_date,
            event_type: "contract_end",
            employee: { id: Account.current.employees.first, manager_id: nil },
            employee_attributes: nil,
          }
        )
      end

      it do
        balances = employee.employee_balances.order(:effective_at)

        expect(balances[0]).to have_attributes(
          balance_type: "assignation",
          balance: 2407,
          resource_amount: 0,
          effective_at: within(10.seconds).of(hired_date.to_time(:utc))
        )
        expect(balances[1]).to have_attributes(
          balance_type: "end_of_contract",
          balance: 1184,
          resource_amount: -1223,
          effective_at: within(10.seconds).of(hired_date.to_time(:utc))
        )
        expect(balances[2]).to have_attributes(
          balance_type: "reset",
          balance: 0,
          resource_amount: -1184,
          effective_at: within(1.day + 10.seconds).of(contract_end_date.to_time(:utc))
        )

        perform_enqueued_jobs do
          subject
          balances.reload
        end

        expect(balances[0]).to have_attributes(
          balance_type: "assignation",
          balance: 2407,
          resource_amount: 0,
          effective_at: within(10.seconds).of(hired_date.to_time(:utc))
        )
        expect(balances[1]).to have_attributes(
          balance_type: "assignation",
          balance: 1480,
          resource_amount: 0,
          effective_at: within(10.seconds).of(effective_at.to_time(:utc))
        )
        expect(balances[2]).to have_attributes(
          balance_type: "end_of_contract",
          balance: 868,
          resource_amount: -612,
          effective_at: within(10.seconds).of(effective_at.to_time(:utc))
        )
        expect(balances[3]).to have_attributes(
          balance_type: "reset",
          balance: 0,
          resource_amount: -868,
          effective_at: within(1.day + 10.seconds).of(contract_end_date.to_time(:utc))
        )
      end
    end
  end
end
