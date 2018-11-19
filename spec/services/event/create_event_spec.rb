require "rails_helper"

RSpec.describe CreateEvent do
  include_context "shared_context_account_helper"

  before do
    Account.current = employee.account
  end

  let!(:definition) do
    create(:employee_attribute_definition,
      account: employee.account, name: attribute_name, multiple: true, validation: { presence: true })
  end
  let!(:occupation_rate_definition) do
    create(:employee_attribute_definition,
      name: "occupation_rate",
      account: employee.account,
      attribute_type: Attribute::Number.attribute_type,
      validation: { range: [0, 1] })
  end
  let!(:presence_policy) do
    create(:presence_policy, :with_time_entries, account: employee.account, occupation_rate: 0.8)
  end
  let(:employee) { create(:employee) }
  let(:manager) { create(:account_user, account: employee.account) }
  let(:employee_id) { employee.id }
  let(:effective_at) { Date.new(2015, 4, 21) }
  let(:event_type) { "work_contract" }
  let(:value) { "abc" }
  let(:attribute_name) { "job_title" }
  let(:attribute_name_second) { "job_title" }
  let(:occupation_rate_attribute) { "occupation_rate" }
  let!(:vacation_category) do
    create(:time_off_category, account: employee.account,
      name: "vacation")
  end
  let(:params) do
    {
      effective_at: effective_at,
      event_type: event_type,
      time_off_policy_amount: 9600,
      employee: {
        id: employee_id,
      },
      presence_policy_id: presence_policy.id,
    }
  end
  let(:employee_attributes_params) do
    [
      {
        value: value,
        attribute_name: attribute_name,
        order: 1,
      },
      {
        value: 0.8,
        attribute_name: occupation_rate_attribute,
        order: 2,
      },
      {
        value: "xyz",
        attribute_name: attribute_name,
        order: 3,
      },
    ]
  end

  subject { described_class.new(params, employee_attributes_params).call }

  context "with valid params" do
    context "when employee_id is present" do
      it { expect { subject }.to change { Employee::AttributeVersion.count }.by(3) }
      it { expect { subject }.to change { employee.events.count }.by(1) }

      it { expect(subject.effective_at).to eq effective_at }
      it { expect(subject.employee_attribute_versions.first.data.line).to eq value }

      context "when manager_id key is present" do
        before do
          params[:employee][:manager_id] = manager_id
        end

        context "when manager is assigned" do
          let(:manager_id) { manager.id }

          it "assigns manager" do
            expect { subject }.to change { employee.reload.manager }.to(manager)
          end
        end

        context "when manager is unassigned" do
          before do
            employee.update!(manager: manager)
          end

          let(:manager_id) { nil }

          it "unassigns manager" do
            expect { subject }.to change { employee.reload.manager }.to(nil)
          end
        end
      end

      context "when manager_id key is not present" do
        before do
          employee.update!(manager: manager)
        end

        it "doesn't change manager" do
          expect { subject }.not_to change { employee.reload.manager }
        end
      end


      context "and this is contract end event" do
        let(:event_type) { "contract_end" }
        let(:category) { create(:time_off_category, account: employee.account) }
        let(:effective_at) { Date.today }
        let!(:etop) do
          create(:employee_time_off_policy,
            employee: employee, effective_at: 2.weeks.ago,
            time_off_policy: create(:time_off_policy, time_off_category: category))
        end
        let!(:time_off) do
          create(:time_off,
            start_time: effective_at - 1.week, end_time: effective_at + 8.hours,
            employee: employee, time_off_category: etop.time_off_category)
        end

        it { expect { subject }.to change { Employee::Event.count } }
        it { expect { subject }.to_not change { time_off.reload.end_time } }
      end

      context "and nested attribute send" do
        let!(:child_definition) do
          create(:employee_attribute_definition,
            account: employee.account, name: "child", attribute_type: "Child",
            validation: { inclusion: true} )
        end

        before do
          employee_attributes_params.unshift(
            {
              attribute_name: "child",
              order: 2,
              value: {
                lastname: "Stark",
                firstname: "Arya",
              },
            }
          )
        end

        it { expect { subject }.to change { Employee::AttributeVersion.count }.by(4) }

        it "has valid data" do
          subject

          expect(subject.employee_attribute_versions
            .where(attribute_definition: child_definition).first.data[:firstname]).to eq "Arya"
        end

        context "other parent work status validation" do
          before do
            employee_attributes_params.first[:value][:other_parent_work_status] = work_status
          end

          context "when other parent work status is valid" do
            let(:work_status) { "salaried employee" }

            it { expect { subject }.to change { Employee::AttributeVersion.count }.by(4) }
            it { expect { subject }.to change { Employee::Event.count }.by(1) }
          end

          context "when other parent work status is invalid" do
            let(:work_status) { "test status" }

            it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
          end
        end
      end

      context "and definition multiple is false" do
        before do
          definition.update(multiple: false)
        end

        it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
      end

      context "and definition has not validation" do
        before { definition.update(validation: nil) }

        let(:value) { nil }

        it { expect { subject }.to change { Employee::AttributeVersion.count }.by(3) }
        it { expect { subject }.to_not raise_error }
      end
    end

    context "when employee_id is not present" do
      let(:event_type) { "hired" }
      let(:value) { "Ned" }
      let(:attribute_name) { "firstname" }
      let(:attribute_name_second) { "nationality" }

      let!(:definition_second) do
        create(:employee_attribute_definition,
          account: employee.account, name: attribute_name_second, multiple: true, validation: nil)
      end

      before do
        definition.update(name: attribute_name)
        params[:employee].delete(:id)
      end

      it { expect { subject }.to change { Employee.count }.by(1) }
      it { expect { subject }.to change { Employee::AttributeVersion.count }.by(3) }

      it { expect(subject.effective_at).to eq effective_at }
      it { expect(subject.employee_attribute_versions.first.data.line).to eq value }

      context "and required attribute is nil or not send" do
        context "and value is nil" do
          let(:value) { nil }

          it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
        end

        context "and required attribute does not send" do
          before { employee_attributes_params.shift(3) }
          it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
        end
      end

      context "and definition does not have validation" do
        before { definition.update(validation: nil) }

        let(:value) { nil }

        it { expect { subject }.to change { Employee::AttributeVersion.count }.by(3) }
        it { expect { subject }.to_not raise_error }
      end

      context "when manager_id key is present" do
        before do
          definition.update(name: "job_title")
          params[:employee][:manager_id] = manager_id
          definition.update(name: attribute_name)
        end

        context "when manager is set" do
          let(:manager_id) { manager.id }

          it "it creates employee with manager" do
            expect { subject }.to change { Employee.where(manager: manager).count }.by(1)
          end
        end

        context "when manager is not set" do
          let(:manager_id) { nil }
          let(:new_employee) { Account.current.employees.order(created_at: :desc).last }

          it "it creates employee without manager" do
            subject
            expect(new_employee.manager).to be_blank
          end
        end
      end
    end
  end

  context "with invalid params" do
    context "and params are nil" do
      let(:params) { nil }

      it { expect { subject }.to raise_error(NoMethodError) }
    end

    context "and definition is not multiple" do
      before { definition.update(multiple: false) }

      it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
    end

    context "and employee attributes params are nil" do
      let(:employee_attributes_params) { nil }

      it { expect { subject }.to raise_error(NoMethodError) }
    end

    context "and employee id is invalid" do
      let(:employee_id) { "abc" }

      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context "and employee id is nil" do
      let(:employee_id) { nil }

      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end
  end
end
