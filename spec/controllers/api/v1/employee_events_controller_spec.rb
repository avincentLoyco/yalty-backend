require "rails_helper"

RSpec.describe API::V1::EmployeeEventsController, type: :controller do
  include_context "shared_context_headers"
  include_context "shared_context_remove_original_helper"

  before do
    Account.current = default_presence.account
    Account.current.update(
      available_modules: ::Payments::AvailableModules.new(data: available_modules)
    )
    allow_any_instance_of(::Payments::UpdateSubscriptionQuantity).to receive(:perform_now).and_return(true)
  end

  shared_examples "Invalid Authorization" do
    context "when current account nil" do
      before { Account.current = nil }

      it { is_expected.to have_http_status(401) }

      context "response body" do
        before { subject }

        it { expect_json(
          errors: [
            {
              field: "error",
              messages: ["User unauthorized"],
              status: "invalid",
              type: "nil_class",
              codes: ["error_user_unauthorized"],
              employee_id: nil,
            },
          ]
        )}
      end
    end

    context "when current user nil" do
      before { Account::User.current = nil }

      it { is_expected.to have_http_status(401) }

      context "response body" do
        before { subject }

        it { expect_json(
          errors: [
            {
              field: "error",
              messages: ["User unauthorized"],
              status: "invalid",
              type: "nil_class",
              codes: ["error_user_unauthorized"],
              employee_id: nil,
            },
          ]
        )}
      end
    end
  end

  let!(:default_presence) do
    create(:presence_policy, :with_time_entries, occupation_rate: 0.5,
      standard_day_duration: 9600, default_full_time: true)
  end

  let(:epp) do
    create(:employee_presence_policy, effective_at: event.effective_at, employee: event.employee)
  end
  let(:repp) do
    create(:employee_presence_policy, effective_at: rehired.effective_at,
           employee: rehired.employee)
  end

  let(:available_modules) { [] }
  let!(:employee_eattribute_definition) do
    create(:employee_attribute_definition,
      account: Account.current,
      name: "address",
      attribute_type: "Address")
  end
  let(:attribute_name) { "profile_picture" }
  let!(:file_definition) do
    create(:employee_attribute_definition, :required_with_nil_allowed,
      account: Account.current,
      name: attribute_name,
      attribute_type: "File"
    )
  end

  let!(:vacation_category) { create(:time_off_category, account: Account.current, name: "vacation") }

  let!(:user) { create(:account_user, employee: employee, role: "account_administrator") }

  let(:employee) do
    create(:employee_with_working_place, :with_attributes,
      account: default_presence.account,
      employee_attributes: {
        firstname: employee_first_name,
        lastname: employee_last_name,
        annual_salary: employee_annual_salary
        # occupation_rate: 0.5
      })
  end
  let(:employee_id) { employee.id }
  let(:employee_first_name) { "John" }
  let(:employee_last_name) { "Doe" }
  let(:employee_annual_salary) { "2000" }
  let(:time_off_policy_amount) { 9600 }
  let(:employee_occupation_rate) { "0.8" }

  let(:event) { employee.events.where(event_type: "hired").first! }
  let(:event_id) { event.id }

  let(:first_name_attribute_definition) { "firstname" }
  let(:occupation_rate_attribute_definition) { "occupation_rate" }
  let(:occupation_rate_attribute) do
    event.employee_attribute_versions.find do |attr|
      attr.attribute_name == "occupation_rate"
    end
  end
  let(:first_name_attribute) do
    event.employee_attribute_versions.find do |attr|
      attr.attribute_name == "firstname"
    end
  end
  let(:first_name_attribute_id) { first_name_attribute.id }

  let(:annual_salary_attribute_definition) { "annual_salary" }
  let(:annual_salary_attribute_id) { annual_salary_attribute.id }
  let(:annual_salary_attribute) do
    event.employee_attribute_versions.find do |attr|
      attr.attribute_name == "annual_salary"
    end
  end

  let(:last_name_attribute_definition) { "lastname" }
  let(:last_name_attribute) do
    event.employee_attribute_versions.find do |attr|
      attr.attribute_name == "lastname"
    end
  end

  let(:last_name_attribute_id) { last_name_attribute.id }
  let!(:occupation_rate_definition) do
    create(:employee_attribute_definition,
      account: default_presence.account,
      name: "occupation_rate",
      attribute_type: "Number",
      validation: { range: [0, 1] })
  end
  let(:occupation_rate_attribute_definition) { "occupation_rate" }
  let(:occupation_rate_attribute) do
    event.employee_attribute_versions.find do |attr|
      attr.attribute_name == "occupation_rate"
    end
  end
  let(:first_pet_name) { "Pluto" }
  let(:second_pet_name) { "Scooby Doo" }
  let!(:multiple_attribute_definition) do
    create(:employee_attribute_definition, :pet_multiple, account: Account.current)
  end
  let(:pet_multiple_attribute) do
    [
      {
        type: "employee_attribute",
        attribute_name: multiple_attribute_definition.name,
        value: first_pet_name,
        order: 1,
      },
      {
        type: "employee_attribute",
        attribute_name: multiple_attribute_definition.name,
        value: second_pet_name,
        order: 2,
      },
    ]
  end
  let!(:presence_policy) do
    create(:presence_policy, :with_time_entries, account: employee.account, occupation_rate: 0.8,
      standard_day_duration: 9600, default_full_time: true)
  end

  shared_examples "Unprocessable Entity on create" do
    context "with two attributes with same name" do
      before do
        attr = json_payload[:employee_attributes].first
        json_payload[:employee_attributes] << attr
      end
      it { expect { subject }.to_not change { Employee::Event.count } }
      it { expect { subject }.to_not change { Employee.count } }
      it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

      it "should respond with 422" do
        expect(subject).to have_http_status(422)
      end
    end

    context "without all required params given" do
      context "for event" do
        before do
          json_payload.delete(:effective_at)
        end

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it "should respond with 422" do
          expect(subject).to have_http_status(422)
        end
      end

      context "for employee attributes" do
        before do
          json_payload[:employee_attributes].first.delete(:attribute_name)
        end

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it "should respond with 422" do
          expect(subject).to have_http_status(422)
        end
      end
    end

    context "with invalid data given" do
      context "for event" do
        let(:effective_at) { "not a date" }

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it "should respond with 422" do
          expect(subject).to have_http_status(422)
        end
      end

      context "for employee attributes" do
        let(:first_name_attribute_definition) { "not a def" }

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it "should respond with 422" do
          expect(subject).to have_http_status(422)
        end
      end

      context "when invalid value type send" do
        let(:last_name) { ["test"] }

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it { is_expected.to have_http_status(422) }

        context "response body" do
          before { subject }

          it { expect(response.body).to include "must be a string"}
        end
      end
    end
  end

  describe "POST #create" do
    subject { post :create, json_payload }
    let(:effective_at) { Date.new(2015, 4, 21) }
    let(:first_name) { "Walter" }
    let(:last_name) { "Smith" }
    let(:event_type) { "hired" }


    context "a new employee" do
      let(:json_payload) do
        {
          type: "employee_event",
          effective_at: effective_at,
          event_type: event_type,
          presence_policy_id: presence_policy.id,
          time_off_policy_amount: 9600,
          employee: {
            type: "employee",
            manager_id: manager_id,
          },
          employee_attributes: [
            {
              attribute_name: first_name_attribute_definition,
              value: first_name,
            },
            {
              attribute_name: last_name_attribute_definition,
              value: last_name,
            },
            {
              attribute_name: occupation_rate_attribute_definition,
              value: 0.8,
            },
          ],
        }
      end

      let(:manager_id) { nil }

      it_behaves_like "Invalid Authorization"

      it { expect { subject }.to change { Employee::Event.count }.by(1) }
      it { expect { subject }.to change { Employee.count }.by(1) }
      it { expect { subject }.to change { Employee::AttributeVersion.count }.by(3) }

      context "when file type attribute send" do
        let(:generic_file) { create(:generic_file) }

        context "when filevault is not subscribed" do
          context "when file type attribute send" do
            let(:generic_file) { create(:generic_file) }

            before do
              allow_any_instance_of(GenericFile).to receive(:find_file_path) do
                ["#{Rails.root}/spec/fixtures/files/test.jpg"]
              end
              json_payload[:employee_attributes].push(
                {
                  type: "employee_attribute",
                  attribute_name: file_definition.name,
                  value: generic_file.id,
                }
              )
            end

            context "when profile_picture sent" do

              it { expect { subject }.to change { generic_file.reload.file_content_type } }
              it { expect { subject }.to change { generic_file.reload.file_file_size } }
              it { expect { subject }.to change { Employee.count } }
              it { expect { subject }.to change { Employee::Event.count } }

              it { is_expected.to have_http_status(201) }
            end

            context "when contract is sent" do
              let(:attribute_name) { "contract" }

              it { expect { subject }.not_to change { Employee.count } }
              it { expect { subject }.not_to change { Employee::Event.count } }

              it { is_expected.to have_http_status(403) }
            end
          end
        end
      end

      context "when filevault is subscribed" do
        let(:available_modules) { [::Payments::PlanModule.new(id: "filevault", canceled: false)] }

        context "when file type attribute send" do
          let(:generic_file) { create(:generic_file) }

          before do
            allow_any_instance_of(GenericFile).to receive(:find_file_path) do
              ["#{Rails.root}/spec/fixtures/files/test.jpg"]
            end
            json_payload[:employee_attributes].push(
              {
                type: "employee_attribute",
                attribute_name: file_definition.name,
                value: generic_file.id,
              }
            )
          end

          context "when profile_picture sent" do

            it { expect { subject }.to change { generic_file.reload.file_content_type } }
            it { expect { subject }.to change { generic_file.reload.file_file_size } }
            it { expect { subject }.to change { Employee.count } }
            it { expect { subject }.to change { Employee::Event.count } }

            it { is_expected.to have_http_status(201) }
          end

          context "when contract is sent" do
            let(:attribute_name) { "contract" }

            it { expect { subject }.to change { generic_file.reload.file_content_type } }
            it { expect { subject }.to change { generic_file.reload.file_file_size } }
            it { expect { subject }.to change { Employee.count } }
            it { expect { subject }.to change { Employee::Event.count } }

            it { is_expected.to have_http_status(201) }
          end
        end
      end

      context "when child attribute send" do
        let!(:child_definition) do
          create(:employee_attribute_definition,
            account: default_presence.account, name: "child", attribute_type: "Child",
            validation: { inclusion: true })
        end

        before do
          json_payload[:employee_attributes].push(
            {
              attribute_name: "child",
              value: {
                firstname: "Jon",
                lastname: "Snow",
                nationality: "CH",
                other_parent_work_status: other_parent_work_status,
              },
            }
          )
        end

        context "with invalid data" do
          let(:other_parent_work_status) { "salaried employee" }

          it { expect { subject }.to change { Employee::Event.count }.by(1) }
          it { expect { subject }.to change { Employee::AttributeVersion.count }.by(4) }
          it { expect { subject }.to change { Employee.count }.by(1) }

          it { is_expected.to have_http_status(201) }
        end

        context "with invalid data" do
          let(:other_parent_work_status) { "Lannister" }

          it { expect { subject }.to_not change { Employee::Event.count } }
          it { expect { subject }.to_not change { Employee::AttributeVersion.count } }
          it { expect { subject }.to_not change { Employee.count } }

          it { is_expected.to have_http_status(422) }
          it do
            subject

            expect(response.body).to include "value not allowed"
          end
        end
      end

      context "when manager_id sent" do
        let(:manager) { create(:account_user, account: employee.account) }
        let(:manager_id) { manager.id }
        let(:new_employee) { default_presence.account.employees.order(created_at: :desc).first }

        it "sets manager" do
          subject
          expect(new_employee.manager).to eq manager
        end
      end

      it "should respond with success" do
        expect(subject).to have_http_status(201)
      end

      it "should contain event data" do
        expect(subject).to have_http_status(:success)

        expect_json_keys([:id, :type, :effective_at, :event_type, :employee])
      end

      it "should have given values" do
        expect(subject).to have_http_status(:success)

        expect_json(event_type: json_payload[:event_type])
      end

      it "should contain employee" do
        expect(subject).to have_http_status(:success)

        expect_json_keys("employee", [:id, :type])
      end

      it "should contain employee attributes" do
        expect(subject).to have_http_status(:success)

        expect_json_keys("employee_attributes.0",
          [:value, :attribute_name, :id, :type, :order])
      end

      it "should create event with multiple pet attributes" do
        json_payload[:employee_attributes] = json_payload[:employee_attributes] +
          pet_multiple_attribute

        expect(subject).to have_http_status(201)
        expect(Employee::AttributeVersion.count).to eq(8)
      end

      it "should create hired event when only occupation rate is send" do
        json_payload[:employee_attributes] = [{ attribute_name: "occupation_rate", value: "0.8" }]

        expect { subject }.to change { Employee::Event.count }.by(1)
      end

      context "when not hired or work contract" do
        before do
          json_payload.delete(:presence_policy_id)
          json_payload[:employee].merge!(id: employee.id)
        end
        let(:event_type) { "default" }

        it "should create event when employee attributes not send" do
          json_payload.delete(:employee_attributes)

          expect { subject }.to change { Employee::Event.count }.by(1)
          expect(subject).to have_http_status(201)
        end
      end
      it "should not create event when employee attributes not send" do
        json_payload.delete(:employee_attributes)
        expect { subject }.to change { Employee.count }.by(0)
        expect(subject).to have_http_status(422)
      end

      context "json payload for nested value" do
        let(:employee_attributes) do
          [{ attribute_name: attribute_definition, value: value },
           { attribute_name: "occupation_rate", value: "0.8" }]
        end
        let(:attribute_definition) { "address" }
        let(:value) { { city: "Wroclaw", country: "Poland" } }

        before { json_payload[:employee_attributes] = employee_attributes }

        it { expect { subject }.to change { Employee::Event.count }.by(1) }
        it { expect { subject }.to change { Employee.count }.by(1) }
        it { expect { subject }.to change { Employee::AttributeVersion.count }.by(2) }

        it { is_expected.to have_http_status(201) }
      end

      it "should not create event and attribute definitions when user is not an account manager" do
        Account::User.current.update!(role: "user")

        expect { subject }.to_not change { Employee::Event.count }
        expect { subject }.to_not change { Employee::AttributeVersion.count }
      end

      context "attributes validations" do
        before do
          Account.current.employee_attribute_definitions
                 .where(name: "lastname").first.update!(validation: { presence: true })
        end

        context "when all params and values are given" do
          it { expect { subject }.to change { Employee::Event.count } }
          it { expect { subject }.to change { Employee.count } }

          it { is_expected.to have_http_status(201) }
        end

        context "when required param is missing" do
          before { json_payload.delete(:employee_attributes) }

          it { expect { subject }.to_not change { Employee::Event.count } }
          it { expect { subject }.to_not change { Employee.count } }

          it { is_expected.to have_http_status(422) }

          context "response body" do
            before { subject }

            it { expect(response.body).to include('["missing params: lastname"]') }
          end
        end

        context "when required param value is set to nil" do
          let(:last_name) { nil }

          it { expect { subject }.to_not change { Employee::Event.count } }
          it { expect { subject }.to_not change { Employee.count } }

          it { is_expected.to have_http_status(422) }

          context "response body" do
            before { subject }

            it { expect(response.body).to include("can't be blank") }
          end
        end
      end

      it_behaves_like "Unprocessable Entity on create"
    end

    context "for an employee that already exist" do
      let(:json_payload) do
        {
          type: "employee_event",
          effective_at: effective_at,
          event_type: "change",
          employee: {
            id: employee_id,
            type: "employee",
          },
          employee_attributes: [
            {
              type: "employee_attribute",
              attribute_name: first_name_attribute_definition,
              value: first_name,
            },
            {
              type: "employee_attribute",
              attribute_name: last_name_attribute_definition,
              value: last_name,
            },
          ],
        }
      end

      context "with new content for attributes" do
        it { expect { subject }.to change { Employee::Event.count }.by(1) }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to change { Employee::AttributeVersion.count }.by(2) }

        it "should respond with success" do
          expect(subject).to have_http_status(201)
        end

        context "when account manager wants to upload a file" do
          let(:generic_file) { create(:generic_file) }

          before do
            allow_any_instance_of(GenericFile).to receive(:find_file_path) do
              ["#{Rails.root}/spec/fixtures/files/test.jpg"]
            end
            json_payload[:employee_attributes].push(
              {
                type: "employee_attribute",
                attribute_name: file_definition.name,
                value: generic_file.id,
              }
            )
          end

          it { expect { subject }.to change { generic_file.reload.file_file_size } }
          it { expect { subject }.to change { generic_file.reload.file_content_type } }
          it { expect { subject }.to change { Employee::AttributeVersion.count } }
          it { expect { subject }.to change { Employee::Event.count } }

          it { is_expected.to have_http_status(201) }

          context "when owner wants to upload a file" do
            before { Account::User.current.update!(role: "user") }

            it { expect { subject }.to change { generic_file.reload.file_file_size } }
            it { expect { subject }.to change { generic_file.reload.file_content_type } }
            it { expect { subject }.to change { Employee::AttributeVersion.count } }
            it { expect { subject }.to change { Employee::Event.count } }

            it { is_expected.to have_http_status(201) }

            context "and file type is forbidden for him" do
              let(:attribute_name) { "salary_slip" }

              it { expect { subject }.to_not change { generic_file.reload.file_file_size } }
              it { expect { subject }.to_not change { generic_file.reload.file_content_type } }
              it { expect { subject }.to_not change { Employee::AttributeVersion.count } }
              it { expect { subject }.to_not change { Employee::Event.count } }

              it { is_expected.to have_http_status(403) }
            end
          end
        end
      end

      context "with same content for attributes" do
        let(:first_name) { employee_first_name }
        let(:last_name) { employee_last_name }

        it { expect { subject }.to change { Employee::Event.count }.by(1) }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to change { Employee::AttributeVersion.count }.by(2) }

        it "should respond with success" do
          expect(subject).to have_http_status(201)
        end
      end

      context "without content for attributes" do
        before do
          json_payload[:employee_attributes] = []
        end

        it { expect { subject }.to change { Employee::Event.count }.by(1) }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it "should respond with success" do
          expect(subject).to have_http_status(201)
        end
      end

      context "with content of attributes to nil" do
        let(:first_name) { nil }

        before do
          json_payload[:employee_attributes].delete_if do |attr|
            attr[:attribute_name] != first_name_attribute_definition
          end
        end

        it { expect { subject }.to change { Employee::Event.count }.by(1) }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to change { Employee::AttributeVersion.count }.by(1) }

        it "should respond with success" do
          expect(subject).to have_http_status(201)
        end
      end

      it_behaves_like "Unprocessable Entity on create"

      context "with wrong id given" do
        context "for employee" do
          let(:employee_id) { "123" }

          it { expect { subject }.to_not change { Employee::Event.count } }
          it { expect { subject }.to_not change { Employee.count } }
          it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

          it "should respond with 404" do
            expect(subject).to have_http_status(404)
          end
        end

        context "when employee wants to create event for other employee" do
          before do
            Account::User.current.update!(
               employee: create(:employee, account: default_presence.account), role: "user"
            )
          end

          it { expect { subject }.to_not change { Employee::Event.count } }
          it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

          it { is_expected.to have_http_status(403) }
        end
      end

      context "with multiple and system attribute definition" do
        let!(:multiple_system_definition) do
          create(:employee_attribute_definition, :multiple, :system, account: Account.current)
        end
        let(:system_multiple_attribute) do
          [
            {
              type: "employee_attribute",
              attribute_name: multiple_system_definition.name,
              value: first_pet_name,
              order: 1,
            },
            {
              type: "employee_attribute",
              attribute_name: multiple_system_definition.name,
              value: second_pet_name,
              order: 2,
            },
          ]
        end
        it "should create event with multiple pet attributes" do
          json_payload[:employee_attributes] = json_payload[:employee_attributes] +
            system_multiple_attribute

          expect(subject).to have_http_status(201)
          expect(Employee::AttributeVersion.count).to eq(7)
        end
      end

      context "when creating adjustment balance event" do
        let(:adjustment_value) { 20 }

        let(:json_payload) do
          {
            type: "employee_event",
            effective_at: event_effective_at,
            event_type: "adjustment_of_balances",
            employee: {
              id: employee_id,
              type: "employee",
            },
            employee_attributes: [
              {
                type: "employee_attribute",
                attribute_name: "adjustment",
                value: adjustment_value,
              },
              {
                type: "employee_attribute",
                attribute_name: "comment",
                value: "correction",
              },
            ],
          }
        end

        let(:event_effective_at) { effective_at }

        let(:time_off_policy) { create(:time_off_policy, time_off_category: vacation_category) }

        let(:employee_adjustment_balance) do
          employee.employee_balances
            .where(balance_type: "manual_adjustment")
            .where(resource_amount: adjustment_value)
        end

        let(:employee_adjustment_events) do
          employee.events.where(event_type: "adjustment_of_balances")
        end

        before do
          create(:employee_attribute_definition,
            account: Account.current,
            name: "adjustment",
            attribute_type: "Number",
            validation: { integer: true }
          )

          create(:employee_attribute_definition,
            account: Account.current,
            name: "comment",
            attribute_type: "String"
          )

          create(:employee_time_off_policy, :with_employee_balance,
            employee: employee, time_off_policy: time_off_policy,
            effective_at: effective_at)

        end

        it "should respond with success" do
          expect(subject).to have_http_status(201)
        end

        it "creates event" do
          expect { subject }.to change { employee_adjustment_events.count }.by(1)
        end

        it "creates adjustment balance" do
          expect { subject }.to change { employee_adjustment_balance.count }.by(1)
        end

        context "when employee has no time off policy at that date" do
          let(:event_effective_at) { effective_at - 1.day }

          it { is_expected.to have_http_status(422) }

          it "doesn't create event" do
            expect { subject }.not_to change { employee_adjustment_events.count }
          end
        end

        context "and current user is not manager" do
          before do
            Account::User.current = create(:account_user, account: account, employee: employee)
          end

          it "should respond with permission denied" do
            expect(subject).to have_http_status(403)
          end
        end

        context "and adjustment event already exist at given date" do
          before do
            post :create, json_payload
          end

          it { is_expected.to have_http_status(422) }

          it "doesn't create event" do
            expect { subject }.not_to change { employee_adjustment_events.count }
          end
        end
      end
    end

    context "rehired event one day after contract end" do
      let(:json_payload) do
        {
          type: "employee_event",
          effective_at: effective_at,
          event_type: event_type,
          employee: { id: employee.id },
          presence_policy_id: presence_policy.id,
          employee_attributes: [
            {
              attribute_name: occupation_rate_attribute_definition,
              value: 0.8,
            },
          ],
          time_off_policy_amount: 9600,
        }
      end

      context "when hired and contract_end exist" do
        let(:event_type) { "hired" }
        let!(:employee_time_off_policy) do
          create(:employee_time_off_policy, :with_employee_balance,
            employee: employee,
            effective_at: employee.events.order(:effective_at).first.effective_at)
        end
        let!(:contract_end) do
          create(:employee_event, employee: employee, event_type: "contract_end",
            effective_at: event.effective_at + 2.months)
        end

        context "when rehired is not right after contract_end" do
          let(:effective_at) { contract_end.effective_at + 7.days }

          it { expect { subject }.to change { Employee::Event.count }.by(1) }
          it { expect { subject }.to_not change { Employee.count } }
        end

        context "when rehired is right after contract_end" do
          let(:effective_at) { contract_end.effective_at + 1.day }

          it { expect { subject }.to change { Employee::Event.count } }

          it { expect { subject }.to_not change { Employee.count } }
          it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(1) }
          it { is_expected.to have_http_status(201) }
        end
      end

      context "create contract_end right after hired" do
        before { json_payload[:employee_attributes] = [] }
        let(:event_type) { "contract_end" }
        let(:effective_at) { event.effective_at + 1.day }

        it { expect { subject }.to change { Employee::Event.count }.by(1) }
        it { expect { subject }.to_not change { Employee.count } }
      end
    end
  end

  shared_examples "Unprocessable Entity on update" do
    context "with invalid data given" do
      context "for event" do
        let(:effective_at) { "not a date" }

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it { expect { subject }.to_not change { event.reload.effective_at } }

        it "should respond with 422" do
          expect(subject).to have_http_status(422)
        end
      end

      context "for employee attributes" do
        let(:first_name_attribute_definition) { "not a def" }

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it { expect { subject }.to_not change { first_name_attribute.reload.attribute_name } }

        it "should respond with 422" do
          expect(subject).to have_http_status(422)
        end
      end
    end

    context "with two attributes with same name" do
      before do
        attr = json_payload[:employee_attributes].first
        json_payload[:employee_attributes] << attr
      end

      it { expect { subject }.to_not change { Employee::Event.count } }
      it { expect { subject }.to_not change { Employee.count } }
      it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

      it { expect { subject }.to_not change { event.reload.effective_at } }

      it "should respond with 422" do
        expect(subject).to have_http_status(422)
      end
    end

    context "with change of attribute definition" do
      let(:first_name_attribute_definition) { last_name_attribute_definition }

      it { expect { subject }.to_not change { Employee::Event.count } }
      it { expect { subject }.to_not change { Employee.count } }
      it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

      it { expect { subject }.to_not change { first_name_attribute.reload.attribute_name } }

      it "should respond with 422" do
        expect(subject).to have_http_status(422)
      end
    end

    context "when invalid value type send" do
      let(:last_name) { ["test"] }

      it { expect { subject }.to_not change { Employee::Event.count } }
      it { expect { subject }.to_not change { Employee.count } }
      it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

      it { is_expected.to have_http_status(422) }

      context "response body" do
        before { subject }

        it { expect(response.body).to include "must be a string" }
      end
    end

    context "with wrong id given" do
      context "for event" do
        let(:event_id) { SecureRandom.uuid }

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it { expect { subject }.to_not change { event.reload.effective_at } }

        it "should respond with 404" do
          expect(subject).to have_http_status(404)
        end
      end

      context "for employee" do
        let(:employee_id) { SecureRandom.uuid }

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it { expect { subject }.to_not change { event.reload.effective_at } }

        it "should respond with 404" do
          expect(subject).to have_http_status(404)
        end
      end

      context "for employee attributes" do
        let(:first_name_attribute_id) { SecureRandom.uuid }

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it { expect { subject }.to_not change { first_name_attribute.reload.value } }

        it "should respond with 404" do
          expect(subject).to have_http_status(404)
        end
      end
    end
  end

  describe "PUT #update" do
    before { event.employee_presence_policy = epp }

    subject { put :update, json_payload }

    let(:json_payload) do
      {
        id: event_id,
        type: "employee_event",
        effective_at: effective_at,
        time_off_policy_amount: 9600,
        event_type: "hired",
        employee: {
          id: employee_id,
          manager_id: manager_id,
          type: "employee",
        },
        presence_policy_id: presence_policy.id,
        employee_attributes: [
          {
            attribute_name: occupation_rate_attribute_definition,
            value: 1.0,
          },
          {
            id: first_name_attribute_id,
            type: "employee_attribute",
            attribute_name: first_name_attribute_definition,
            value: first_name,
          },
          {
            id: last_name_attribute_id,
            type: "employee_attribute",
            attribute_name: last_name_attribute_definition,
            value: last_name,
          },
          {
            id: annual_salary_attribute_id,
            type: "employee_attribute",
            attribute_name: annual_salary_attribute_definition,
            value: annual_salary,
          },
        ],
      }
    end

    it_behaves_like "Invalid Authorization"

    let(:effective_at) { Date.new(2015, 4, 21) }

    let(:first_name) { "Walter" }
    let(:last_name) { "Smith" }
    let(:annual_salary) { "300" }

    let(:manager_id) { nil }

    context "with change in all fields and added occupation rate" do
      it { expect { subject }.to_not change { Employee::Event.count } }
      it { expect { subject }.to_not change { Employee.count } }
      it { expect { subject }.to change { Employee::AttributeVersion.count }.by(1) }

      it { expect { subject }.to change { event.reload.effective_at }.to(effective_at) }

      it { expect { subject }.to change { first_name_attribute.reload.value }.to(first_name) }
      it { expect { subject }.to change { last_name_attribute.reload.value }.to(last_name) }
      it { expect { subject }.to change { annual_salary_attribute.reload.value }.to(annual_salary) }

      it "should respond with success" do
        expect(subject).to have_http_status(204)
      end
    end

    context "when account user wants to add file" do
      let(:generic_file) { create(:generic_file) }
      let(:file_value) { generic_file.id }

      before do
        json_payload[:employee_attributes].pop
        allow_any_instance_of(GenericFile).to receive(:find_file_path) do
          ["#{Rails.root}/spec/fixtures/files/test.jpg"]
        end
        json_payload[:employee_attributes].push(
          {
            type: "employee_attribute",
            attribute_name: file_definition.name,
            value: file_value,
          }
        )
      end

      it { expect { subject }.to change { generic_file.reload.file_content_type  } }
      it { expect { subject }.to change { generic_file.reload.file_file_size } }
      it { expect { subject }.to change { last_name_attribute.reload.value } }
      it { expect { subject }.to change { first_name_attribute.reload.value } }

      it { is_expected.to have_http_status(204) }

      context "and he is not an account manager" do
        before do
          Account::User.current = create(:account_user, account: account, employee: employee)

          json_payload[:employee_attributes].delete_if do |attr|
            attr[:attribute_name] == annual_salary_attribute_definition
          end
          annual_salary_attribute.destroy
        end

        it { expect { subject }.to change { generic_file.reload.file_content_type  } }
        it { expect { subject }.to change { generic_file.reload.file_file_size } }

        it { is_expected.to have_http_status(204) }

        context "and its is in forbidden type" do
          let(:attribute_name) { "salary_slip" }

          it { expect { subject }.to_not change { generic_file.reload.file_content_type  } }
          it { expect { subject }.to_not change { generic_file.reload.file_file_size } }
          it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

          it { is_expected.to have_http_status(403) }

          it "has valid error in response body" do
            subject

            expect(response.body).to include "Not authorized!"
          end
        end

        context "and he wants to update event of other employee" do
          before do
            Account::User.current = create(:account_user, account: account)
          end

          it { expect { subject }.to_not change { generic_file.reload.file_content_type  } }
          it { expect { subject }.to_not change { generic_file.reload.file_file_size } }
          it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

          it { is_expected.to have_http_status(403) }
        end
      end
    end

    context "when effective_at changes" do
      context "and event is first employee event" do
        let(:effective_at) { Time.now + 3.months }
        let(:first_working_place) { employee.employee_working_places.order(:effective_at).first }

        context "and there are not new working places between old and new effective_at" do
          it { expect { subject }.to change { first_working_place.reload.effective_at } }
        end

        context "and there are new working places between old and new effective_at" do
          let!(:second_working_place) do
            create(:employee_working_place, employee: employee, effective_at: Time.now + 1.month)
          end
          let!(:third_working_place) do
            create(:employee_working_place, employee: employee, effective_at: Time.now + 2.months)
          end

          it { expect { subject }.to change { third_working_place.reload.effective_at } }
          it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(-2) }
          it do
            expect { subject }.to change { EmployeeWorkingPlace.exists?(second_working_place.id) }
          end
          it do
            expect { subject }.to change { EmployeeWorkingPlace.exists?(first_working_place.id) }
          end
        end
      end
    end

    context "when the user is not an account manager"do
      before { user.role = "user" }

      context "and he wants to update other employee attributes" do
        before do
          user.employee = create(:employee, account: default_presence.account)
          json_payload[:employee_attributes].pop
        end

        it { expect { subject }.to_not change { first_name_attribute.reload.value } }
        it { expect { subject }.to_not change { last_name_attribute.reload.value } }
        it { expect { subject }.to_not change { annual_salary_attribute.reload.value } }

        it { is_expected.to have_http_status(403) }

        it { expect(subject.body).to include("You are not authorized to access this page") }
      end

      context "and there is a forbidden attribute in the payload" do
        context "and it has been updated" do
          it "should respond with error" do
            expect(subject).to have_http_status(403)
            expect(subject.body).to include("Not authorized!")
          end
        end

        context "and it has not been updated" do
          let(:annual_salary) { employee_annual_salary }

          it { expect { subject }.to_not change { Employee::Event.count } }
          it { expect { subject }.to_not change { Employee.count } }
          it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

          it { expect { subject }.to_not change { event.reload.effective_at } }

          it { expect { subject }.to_not change { first_name_attribute.reload.value } }
          it { expect { subject }.to_not change { last_name_attribute.reload.value } }
          it { expect { subject }.to_not change { annual_salary_attribute.reload.value } }
        end
      end

      context "and there is not a forbidden attribute payload" do
        before do
          json_payload[:employee_attributes].delete_if do |attr|
            attr[:attribute_name] == annual_salary_attribute_definition
          end
          annual_salary_attribute.destroy
        end
        context "with change in all fields" do
          it { expect { subject }.to_not change { Employee::Event.count } }
          it { expect { subject }.to_not change { Employee.count } }
          it { expect { subject }.to change { Employee::AttributeVersion.count }.by(1) }

          it { expect { subject }.to change { event.reload.effective_at }.to(effective_at) }

          it { expect { subject }.to change { first_name_attribute.reload.value }.to(first_name) }
          it { expect { subject }.to change { last_name_attribute.reload.value }.to(last_name) }

          it "should respond with success" do
            expect(subject).to have_http_status(204)
          end
        end
      end
    end

    context "when only occupation rate is sent" do
      before do
        json_payload[:employee_attributes] = [{ attribute_name: "occupation_rate", value: "1.0" }]
      end

      it { expect { subject }.to change { event.reload.effective_at }.to(effective_at) }
      it { is_expected.to have_http_status(204) }
    end

    context "attributes validations" do
      before do
        Account.current.employee_attribute_definitions
               .where(name: "lastname").first.update!(validation: { presence: true })
      end

      context "when all params and values are given" do
        it { expect { subject }.to change { last_name_attribute.reload.value } }
        it { is_expected.to have_http_status(204) }
      end

      context "when required param is missing" do
        before { json_payload.delete(:employee_attributes) }

        it { expect { subject }.to_not change { last_name_attribute.reload.value } }
        it { is_expected.to have_http_status(422) }

        context "response body" do
          before { subject }

          it { expect(response.body).to include('["missing params: lastname"]') }
        end
      end

      context "when required param value is set to nil" do
        let(:last_name) { nil }

        it { expect { subject }.to_not change { last_name_attribute.reload.value } }
        it { is_expected.to have_http_status(422) }

        context "response body" do
          before { subject }

          it { expect(response.body).to include("can't be blank") }
        end
      end
    end

    context "without an attribute than be removed" do
      before do
        json_payload[:employee_attributes].delete_if do |attr|
          attr[:attribute_name] == last_name_attribute_definition
        end
      end

      it { expect { subject }.to_not change { Employee::Event.count } }
      it { expect { subject }.to_not change { Employee.count } }
      it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

      it { expect { subject }.to change { first_name_attribute.reload.value }.to(first_name) }

      it "should respond with success" do
        expect(subject).to have_http_status(204)
      end
    end

    context "with an attribute than be added" do
      before do
        last_name_attribute.destroy

        employee.reload
        event.reload

        json_payload[:employee_attributes].each do |attr|
          if attr[:attribute_name] == last_name_attribute_definition
            attr.delete(:id)
          end
        end
      end

      it { expect { subject }.to_not change { Employee::Event.count } }
      it { expect { subject }.to_not change { Employee.count } }
      it { expect { subject }.to change { Employee::AttributeVersion.count } }

      it "should have new attribute version with given value" do
        expect(subject).to have_http_status(:success)

        last_name_attribute = event.reload.employee_attribute_versions.find do |attr|
          attr.attribute_name == last_name_attribute_definition
        end

        expect(last_name_attribute.value).to eql(last_name)
      end

      it "should respond with success" do
        expect(subject).to have_http_status(204)
      end
    end

    context "with content of attributes to nil" do
      let(:first_name) { nil }

      it { expect { subject }.to_not change { Employee::Event.count } }
      it { expect { subject }.to_not change { Employee.count } }
      it { expect { subject }.to change { Employee::AttributeVersion.count } }

      it "should set value to nil" do
        expect { subject }.to change { first_name_attribute.reload.value }.to(nil)
      end

      it "should respond with success" do
        expect(subject).to have_http_status(204)
      end
    end

    it_behaves_like "Unprocessable Entity on update"

    context "without all params given" do
      context "for event" do
        before do
          json_payload.delete(:effective_at)
        end

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it { expect { subject }.to_not change { event.reload.effective_at } }

        it "should respond with 422" do
          expect(subject).to have_http_status(422)
        end
      end

      context "for employee attribute name" do
        before do
          attr_json = json_payload[:employee_attributes].find do |attr|
            attr[:attribute_name] == first_name_attribute_definition
          end

          attr_json.delete(:attribute_name)
        end

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it { expect { subject }.to_not change { first_name_attribute.reload.value } }

        it "should respond with 422" do
          expect(subject).to have_http_status(422)
        end
      end

      context "for employee attribute value" do
        before do
          attr_json = json_payload[:employee_attributes].find do |attr|
            attr[:attribute_name] == first_name_attribute_definition
          end

          attr_json.delete(:value)
        end

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it { expect { subject }.to_not change { first_name_attribute.reload.value } }

        it "should respond with 422" do
          expect(subject).to have_http_status(422)
        end
      end
    end

    context "with new multiple attributes" do
      it "should update event and create multiple pet attributes" do
        json_payload[:employee_attributes] = json_payload[:employee_attributes] +
          pet_multiple_attribute

        expect(subject).to have_http_status(204)
        expect(Employee::AttributeVersion.count).to eq(6)
        expect(
          employee.reload.employee_attribute_versions.map(&:value)
        ).to include(
          pet_multiple_attribute.first[:value], pet_multiple_attribute.last[:value]
        )
      end

      it "should update multiple attributes" do
        av = employee.employee_attribute_versions.new(
          attribute_definition: multiple_attribute_definition,
          employee_event_id: event_id,
          multiple: true,
          order: 4
        )
        av.value = "ABC"
        av.save!

        av = employee.employee_attribute_versions.new(
          attribute_definition: multiple_attribute_definition,
          employee_event_id: event_id,
          multiple: true,
          order: 5
        )
        av.value = "CDE"
        av.save!

        multiple = employee.employee_attribute_versions.where(multiple: true)
        first_pet = pet_multiple_attribute.first.merge(id: multiple.first.id)
        last_pet = pet_multiple_attribute.last.merge(id: multiple.last.id)

        json_payload[:employee_attributes] = json_payload[:employee_attributes] +
          [first_pet, last_pet]

        expect(subject).to have_http_status(204)
        expect(
          employee.reload.employee_attribute_versions.map(&:value)
        ).to include(
          first_pet[:value], last_pet[:value]
        )
      end
    end

    context "restrictions for rehired event" do
      let!(:time_off_policy) { create(:time_off_policy, time_off_category: vacation_category) }
      let!(:etop) do
        create(:employee_time_off_policy, :with_employee_balance,
          employee: employee, time_off_policy: time_off_policy,
          effective_at: employee.events.order(:effective_at).first.effective_at)
      end
      let!(:etop_at_rehired) do
        create(:employee_time_off_policy,
          :with_employee_balance,
          employee: employee,
          effective_at: rehired.effective_at,
          time_off_policy: time_off_policy,
          employee_event: rehired
        )
      end
      let!(:contract_end) do
        create(:employee_event, employee: employee, event_type: "contract_end",
          effective_at: event.effective_at + 2.months)
      end
      let!(:rehired) do
        create(:employee_event, employee: employee, event_type: "hired",
          effective_at: contract_end.effective_at + 2.months)
      end
      let(:json_payload) do
        {
          id: update_event_id,
          event_type: event_type,
          effective_at: effective_at,
          time_off_policy_amount: 9600,
          employee: { id: employee.id },
          type: "employee_event",
          presence_policy_id: presence_policy.id,
        }
      end

      context "when moving rehired right after contract_end" do
        before do
          json_payload.merge!(employee_attributes:
            [
              { attribute_name: "occupation_rate", value: "1.0" },
            ])
          rehired.employee_presence_policy = repp
        end
        let(:update_event_id) { rehired.id }
        let(:event_type) { rehired.event_type }
        let(:effective_at) { contract_end.effective_at + 1.day }


        it { expect { subject }.to change { rehired.reload.effective_at } }
        it { expect { subject }.to change { EmployeeTimeOffPolicy.with_reset.count }.by(-1) }
        it { expect { subject }.to change { etop_at_rehired.reload.effective_at } }
        it do
          expect { subject }.to_not change { Employee::Balance.where(balance_type: "reset").count }
        end

        it { is_expected.to have_http_status(204) }
      end

      context "when moving contract_end right before rehired" do
        let(:update_event_id) { contract_end.id }
        let(:event_type) { contract_end.event_type }
        let(:effective_at) { rehired.effective_at - 1.day }

        it { expect { subject }.to change { contract_end.reload.effective_at} }
        it { expect { subject }.to change { EmployeeTimeOffPolicy.with_reset.count }.by(-1) }
        it do
          expect { subject }.to_not change { Employee::Balance.where(balance_type: "reset").count }
        end

        it { is_expected.to have_http_status(204) }
      end

      context "when moving contract_end right after hired" do
        let(:update_event_id) { contract_end.id }
        let(:event_type) { contract_end.event_type }
        let(:effective_at) { event.effective_at + 1.day }

        it { expect { subject }.to change { contract_end.reload.effective_at }.to(effective_at) }
      end

      context "when moving hired right before contract_end" do
        let(:update_event_id) { event.id }
        let(:event_type) { event.event_type }
        let(:effective_at) { contract_end.effective_at - 1.day }

        it { expect { subject }.to change { event.reload.effective_at }.to(effective_at) }
      end
    end

    context "when updating adjustment balance event" do
      let(:adjustment_value) { 50 }

      let(:json_payload) do
        {
          id: adjustment_event.id,
          type: "employee_event",
          effective_at: event_effective_at,
          event_type: "adjustment_of_balances",
          employee: {
            id: employee.id,
            type: "employee",
          },
          employee_attributes: [
            {
              type: "employee_attribute",
              attribute_name: "adjustment",
              value: adjustment_value,
            },
            {
              type: "employee_attribute",
              attribute_name: "comment",
              value: "new correction",
            },
          ],
        }
      end

      let(:time_off_policy) { create(:time_off_policy, time_off_category: vacation_category) }
      let(:event_effective_at) { effective_at }

      let(:adjustment_event) do
        Events::Adjustment::Create.call(
          effective_at: 5.days.from_now,
          event_type: "adjustment_of_balances",
          employee: {
            id: employee.id,
            type: "employee",
          },
          employee_attributes: [
            {
              type: "employee_attribute",
              attribute_name: "adjustment",
              value: 0,
            },
          ]
        )
      end

      let(:adjustment_balance) do
        Events::Adjustment::Update.new(adjustment_event.reload, {}).adjustment_balance
      end

      before do
        create(:employee_attribute_definition, :required,
          account: Account.current,
          name: "adjustment",
          attribute_type: "Number"
        )

        create(:employee_attribute_definition,
          account: Account.current,
          name: "comment",
          attribute_type: "String"
        )

        create(:employee_time_off_policy, :with_employee_balance,
          employee: employee, time_off_policy: time_off_policy,
          effective_at: effective_at
        )

        adjustment_event
      end

      it "should respond with success" do
        expect(subject).to have_http_status(:no_content)
      end

      it "updates event attributes" do
        expect { subject }
          .to change { adjustment_event.reload.attribute_values }
          .to({"adjustment" => "50", "comment"=>"new correction"})
      end

      it "updates adjustment balance" do
        subject

        expect(adjustment_balance.effective_at)
          .to eq(effective_at + Employee::Balance::MANUAL_ADJUSTMENT_OFFSET)
        expect(adjustment_balance.resource_amount).to eq(50)
      end

      context "and current user is not manager" do
        before do
          Account::User.current = create(:account_user, account: account, employee: employee)
        end

        it "should respond with permission denied" do
          expect(subject).to have_http_status(403)
        end
      end

      context "when employee has no time off policy at that date" do
        let(:event_effective_at) { effective_at - 1.day }

        it { is_expected.to have_http_status(422) }

        it "doesn't update event attributes" do
          expect { subject }.not_to change { adjustment_event.reload.attribute_values }
        end
      end
    end

    context "when updating manager" do
      let(:manager) { create(:account_user, account: employee.account) }
      let(:manager_id) { manager.id }

      it "updates manager" do
        expect { subject }.to change { employee.reload.manager }.to manager
      end
    end
  end

  context "GET #index" do
    context "when employee_id specified" do
      before(:each) do
        create_list(:employee_event, 3, account: default_presence.account, employee: employee)
      end

      let(:subject) { get :index, employee_id: employee.id }

      it_behaves_like "Invalid Authorization"

      it "should respond with success" do
        subject

        expect(response).to have_http_status(:success)
        expect_json_sizes(4)
      end

      it "should have employee events attributes" do
        subject

        expect_json_keys("*", [:effective_at, :event_type, :employee])
      end

      it "should have employee" do
        subject

        expect_json_keys("*.employee", [:id, :type])
      end

      it "should not be visible in context of other account" do
        user = create(:account_user)
        Account.current = user.account

        subject

        expect(response).to have_http_status(404)
      end

      it "should return 404 when invalid employee id" do
        get :index, employee_id: "12345678-1234-1234-1234-123456789012"

        expect(response).to have_http_status(404)
      end

      context "with regular user role" do
        let(:user) { create(:account_user, account: default_presence.account, employee: employee, role: "user") }

        it "should respond with success" do
          subject

          expect(response).to have_http_status(:success)
          expect_json_sizes(4)
        end
      end
    end

    context "when employee_id isn't specified" do
      let!(:second_employee) do
        create(:employee_with_working_place, :with_attributes, account: default_presence.account)
      end

      before(:each) do
        create_list(:employee_event, 3, account: default_presence.account, employee: employee)
        create_list(:employee_event, 2, account: default_presence.account, employee: second_employee)
      end

      let(:subject) { get :index }

      context "when account owner" do
        it "should respond with success" do
          subject

          expect(response).to have_http_status(:success)
          expect_json_sizes(7)
        end

        it "should have employee events attributes" do
          subject

          expect_json_keys("*", [:effective_at, :event_type, :employee])
        end

        it "should have employee" do
          subject

          expect_json_keys("*.employee", [:id, :type])
        end
      end

      context "with regular user role" do
        let(:user) { create(:account_user, account: account, employee: employee, role: "user") }
        it "shoud respond with authorization error" do
          subject

          expect(response.body).to include "not authorized"
        end
      end
    end
  end

  context "GET #show" do
    subject { get :show, id: event.id }

    it_behaves_like "Invalid Authorization"

    it "should respond with success" do
      subject

      expect(response).to have_http_status(:success)
    end

    it "should have employee events attributes" do
      subject

      expect_json_keys([:effective_at, :event_type, :employee])
    end

    it "should have employee" do
      subject

      expect_json_keys("employee", [:id, :type])
    end

    it "should have employee attributes" do
      subject

      expect_json_keys("employee_attributes.0", [:value, :attribute_name, :id, :type, :order])
    end

    it "should respond with 404 when not user event" do
      user = create(:account_user)
      Account.current = user.account

      subject

      expect(response).to have_http_status(404)
    end

    it "should respond with 404 when invalid id" do
      get :show, id: "12345678-1234-1234-1234-123456789012"

      expect(response).to have_http_status(404)
    end

    context "if current_user is not the empoyee requested" do
      subject { get :show, id: event_id }

      context "when current user is an administrator" do
        let!(:user) { create(:account_user, account: default_presence.account, role: "account_administrator") }

        it "should include some attributes" do
          subject
          event_attributes = employee.events.first.employee_attribute_versions
          public_attributes = event_attributes.visible_for_other_employees
          not_public_attributes =
            event_attributes
            .joins(:attribute_definition)
            .where
            .not(employee_attribute_definitions:
              { name: ActsAsAttribute::PUBLIC_ATTRIBUTES_FOR_OTHERS })

          public_attributes.each do |attr|
            expect(response.body).to include(attr.attribute_name)
          end

          not_public_attributes.each do |attr|
            expect(response.body).to include(attr.attribute_name)
          end
        end
      end

      context "when current user is a standard user" do
        let!(:user) { create(:account_user, account: default_presence.account, role: "user") }

        it "should not include some attributes" do
          subject
          event_attributes = employee.events.first.employee_attribute_versions
          public_attributes = event_attributes.visible_for_other_employees
          not_public_attributes =
            event_attributes
            .joins(:attribute_definition)
            .where
            .not(employee_attribute_definitions:
              { name: ActsAsAttribute::PUBLIC_ATTRIBUTES_FOR_OTHERS })

          public_attributes.each do |attr|
            expect(response.body).to include(attr.attribute_name)
          end

          not_public_attributes.each do |attr|
            expect(response.body).to_not include(attr.attribute_name)
          end
        end
      end
    end

    context "with regular user role" do
      let(:user) do
        create(:account_user, account: default_presence.account, employee: employee, role: "user")
      end

      it "should respond with success" do
        subject

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "DELETE #destroy" do
    shared_examples "cannot destroy event" do
      before { delete_event }

      it { expect(response.status).to eq(403) }
      it { expect(response.body).to match("Event cannot be destroyed") }
    end


    subject(:delete_event) { delete :destroy, { id: event_to_delete_id } }

    before { employee.employee_working_places.map(&:destroy!) }

    context "removing hired event" do
      let(:event_to_delete_id) { event.id }

      it_behaves_like "Invalid Authorization"
      context "with other events after" do
        let!(:other_event) do
          create(:employee_event, employee: employee, effective_at: event.effective_at + 1.month)
        end

        it_behaves_like "cannot destroy event"
      end

      context "without other events after" do
        context "with assigned time_off_policies" do
          let!(:etop) do
            create(:employee_time_off_policy, :with_employee_balance, employee: employee,
              effective_at: event.effective_at + 1.month)
          end

          it_behaves_like "cannot destroy event"
        end

        context "with assigned presence_policy" do
          let!(:epp) do
            create(:employee_presence_policy, employee: employee,
              effective_at: event.effective_at + 1.month)
          end

          it_behaves_like "cannot destroy event"
        end

        context "with assigned working_place" do
          let!(:ewp) do
            create(:employee_working_place, employee: employee,
              effective_at: event.effective_at + 1.month)
          end

          it_behaves_like "cannot destroy event"
        end

        context "without assigned join tables" do
          context "response" do
            before { delete_event }

            it { expect(response.status).to eq(204) }
          end

          context "UpdateSubscriptionQuantity job" do
            it "is scheduled" do
              expect(::Payments::UpdateSubscriptionQuantity).to receive(:perform_now).with(default_presence.account)
              delete_event
            end
          end

          context "RemoveEmployee service" do
            it { expect { delete_event }.to change { Employee.count } }
            it { expect { delete_event }.to change { Account::User.count } }
            it { expect { delete_event }.to change { Employee::Event.count } }
          end
        end
      end
    end

    context "when this is second hired event" do
      let!(:contract_end) do
        create(:employee_event, employee: employee, event_type: "contract_end",
          effective_at: event.effective_at + 1.month)
      end
      let!(:rehired) do
        create(:employee_event, employee: employee, event_type: "hired",
          effective_at: contract_end.effective_at + 1.month)
      end
      let(:event_to_delete_id) { rehired.id }

      context "RemoveEmployee service" do
        it "is not invoked" do
          expect(RemoveEmployee).to_not receive(:new).with(employee)
          delete_event
        end
      end

      context "with ETOP and reset policy in previous hired period" do
        let!(:etop) do
          create(:employee_time_off_policy, :with_employee_balance, employee: employee,
            effective_at: event.effective_at)
        end

        before { delete_event }

        it { expect(response.status).to eq(204) }
      end

      context "with ETOP and reset policy in current hired period" do
        let!(:etop) do
          create(:employee_time_off_policy, :with_employee_balance, employee: employee,
            effective_at: rehired.effective_at)
        end

        it_behaves_like "cannot destroy event"
      end

      context "without ETOP" do
        before { delete_event }

        it { expect(response.status).to eq(204) }
      end

      context "with EPP and reset policy in previous hired period" do
        let!(:epp) do
          create(:employee_presence_policy, employee: employee, effective_at: event.effective_at)
        end

        before { delete_event }

        it { expect(response.status).to eq(204) }
      end

      context "with EPP and reset policy in current hired period" do
        let!(:epp) do
          create(:employee_presence_policy, employee: employee, effective_at:rehired.effective_at)
        end

        it_behaves_like "cannot destroy event"
      end

      context "without EPP" do
        before { delete_event }

        it { expect(response.status).to eq(204) }
      end

      context "with EWP and reset policy in previous hired period" do
        let!(:ewp) do
          create(:employee_working_place, employee: employee, effective_at: event.effective_at)
        end

        before { delete_event }

        it { expect(response.status).to eq(204) }
      end

      context "with EWP and reset policy in current hired period" do
        let!(:epp) do
          create(:employee_working_place, employee: employee, effective_at:rehired.effective_at)
        end

        it_behaves_like "cannot destroy event"
      end

      context "without EWP" do
        before { delete_event }

        it { expect(response.status).to eq(204) }
      end
    end

    context "removing contract_end" do
      let(:contract_end) do
        create(:employee_event, employee: employee, effective_at: Time.zone.today,
          event_type: "contract_end")
      end
      let(:event_to_delete_id) { contract_end.id }

      context "without rehired" do
        context "when employee does not have join tables assigned" do
          before { delete_event }

          it { expect(response.status).to eq(204) }
        end

        context "when employee has join tables assigned" do
          before do
            create(:employee_working_place, employee: employee, effective_at: 1.year.ago)
            create(:employee_presence_policy, employee: employee, effective_at: 1.year.ago)
            categories = create_list(:time_off_category, 2, account: default_presence.account)
            policies =
              categories.map do |category|
                create(:time_off_policy, time_off_category: category)
              end
            policies.map do |policy|
              create(:employee_time_off_policy, :with_employee_balance,
                employee: employee, effective_at: 1.year.ago, time_off_policy: policy)
            end
            create(:employee_time_off_policy, :with_employee_balance,
              employee: employee, effective_at: 2.years.ago, time_off_policy: policies.first)
            contract_end
          end

          it { expect { subject }.to change { EmployeePresencePolicy.with_reset.count }.by(-1) }
          it { expect { subject }.to change { EmployeeWorkingPlace.with_reset.count }.by(-1) }
          it { expect { subject }.to change { EmployeeTimeOffPolicy.with_reset.count }.by(-2) }
          it do
            expect { subject }
              .to change { Employee::Balance.where(balance_type: "reset").count }.by(-2)
          end
          it do
            expect { subject }.to change { Employee::Balance.where(balance_type: "addition").count }
          end

          it { is_expected.to have_http_status(204) }
        end
      end

      context "with rehired after" do
        let!(:rehired) do
          create(:employee_event, employee: employee, event_type: "hired",
            effective_at: contract_end.effective_at + 1.month)
        end

        it_behaves_like "cannot destroy event"
      end

      context "UpdateSubscriptionQuantity job" do
        it "is scheduled" do
          expect(::Payments::UpdateSubscriptionQuantity).to receive(:perform_now).with(default_presence.account)
          delete_event
        end
      end
    end

    context "when removing adjustment balance event" do
      let(:adjustment_value) { 50 }


      let(:time_off_policy) { create(:time_off_policy, time_off_category: vacation_category) }

      let(:event_to_delete_id) { adjustment_event.id }

      let(:adjustment_event) do
        Events::Adjustment::Create.call(
          effective_at: 5.days.from_now,
          event_type: "adjustment_of_balances",
          employee: {
            id: employee.id,
            type: "employee",
          },
          employee_attributes: [
            {
              type: "employee_attribute",
              attribute_name: "adjustment",
              value: 0,
            },
          ]
        )
      end

      let(:adjustment_balance) do
        Events::Adjustment::Update.new(adjustment_event.reload, {}).adjustment_balance
      end

      before do
        create(:employee_attribute_definition, :required,
          account: Account.current,
          name: "adjustment",
          attribute_type: "Number"
        )

        create(:employee_attribute_definition,
          account: Account.current,
          name: "comment",
          attribute_type: "String"
        )

        create(:employee_time_off_policy, :with_employee_balance,
          employee: employee, time_off_policy: time_off_policy,
          effective_at: employee.events.order(:effective_at).last.effective_at
        )

        adjustment_balance
      end

      it "should respond with success" do
        expect(subject).to have_http_status(:no_content)
      end

      it "deletes event" do
        expect { subject }
          .to change { Employee::Event.exists?(adjustment_event.id) }
          .from(true).to(false)
      end

      it "delets adjustment balance" do
        expect { subject }
          .to change { Employee::Balance.exists?(adjustment_balance.id) }
          .from(true).to(false)
      end
    end


    context "removing any other event" do
      let!(:any_other_event) do
        create(:employee_event, employee: employee, effective_at: event.effective_at + 1.month)
      end
      let(:event_to_delete_id) { any_other_event.id }

      context "response" do
        before { delete_event }

        it { expect(response.status).to eq(204) }
      end

      context "UpdateSubscriptionQuantity job" do
        it "is not scheduled" do
          expect(::Payments::UpdateSubscriptionQuantity).to_not receive(:perform_now).with(account)
          delete_event
        end
      end

      context "wrong employee" do
        let!(:user) { create(:account_user, role: "user") }
        let!(:other_employee) { create(:employee, account: default_presence.account) }
        let!(:event) { create(:employee_event, employee: other_employee) }
        let(:event_to_delete_id) { event.id }

        before { delete_event }

        it { expect(response.status).to eq(403) }
        it { expect(response.body).to match("You are not authorized to access this page.") }
      end
    end
  end
end
