require 'rails_helper'

RSpec.describe API::V1::EmployeeEventsController, type: :controller do
  include_examples 'example_authorization',
    resource_name: 'employee_event'
  include_context 'shared_context_headers'

  let!(:employee_eattribute_definition) do
    create(:employee_attribute_definition,
      account: Account.current,
      name: 'address',
      attribute_type: 'Address'
    )
  end
  let!(:employee) do
    create(:employee, :with_attributes,
      account: account,
      account_user_id: user.id,
      event: {
        event_type: 'hired',
        effective_at: 2.days.from_now.at_beginning_of_day
      },
      employee_attributes: {
        firstname: employee_first_name,
        lastname: employee_last_name,
        annual_salary: employee_annual_salary
      }
    )
  end
  let(:employee_id) { employee.id }
  let(:employee_first_name) { 'John' }
  let(:employee_last_name) { 'Doe' }
  let(:employee_annual_salary) { '2000' }

  let!(:event) { employee.events.where(event_type: 'hired').first! }
  let(:event_id) { event.id }

  let(:first_name_attribute_definition) { 'firstname'}
  let(:first_name_attribute) do
    event.employee_attribute_versions.find do |attr|
      attr.attribute_name == 'firstname'
    end
  end
  let(:first_name_attribute_id) { first_name_attribute.id }

  let(:annual_salary_attribute_definition) { 'annual_salary'}
  let(:annual_salary_attribute_id) { annual_salary_attribute.id }
  let(:annual_salary_attribute) do
    event.employee_attribute_versions.find do |attr|
      attr.attribute_name == 'annual_salary'
    end
  end

  let(:last_name_attribute_definition) { 'lastname'}
  let(:last_name_attribute) do
    event.employee_attribute_versions.find do |attr|
      attr.attribute_name == 'lastname'
    end
  end
  let(:last_name_attribute_id) { last_name_attribute.id }
  let(:first_pet_name) { 'Pluto' }
  let(:second_pet_name) { 'Scooby Doo' }
  let!(:multiple_attribute_definition) do
    create(:employee_attribute_definition, :pet_multiple, account: Account.current)
  end
  let(:pet_multiple_attribute) do
    [
      {
        type: "employee_attribute",
        attribute_name: multiple_attribute_definition.name,
        value: first_pet_name,
        order: 1
      },
      {
        type: "employee_attribute",
        attribute_name: multiple_attribute_definition.name,
        value: second_pet_name,
        order: 2
      }
    ]
  end

  shared_examples 'Unprocessable Entity on create' do
    context 'with two attributes with same name' do
      before do
        attr = json_payload[:employee_attributes].first
        json_payload[:employee_attributes] << attr
      end

      it { expect { subject }.to_not change { Employee::Event.count } }
      it { expect { subject }.to_not change { Employee.count } }
      it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

      it 'should respond with 422' do
        expect(subject).to have_http_status(422)
      end
    end

    context 'without all required params given' do
      context 'for event' do
        before do
          json_payload.delete(:effective_at)
        end

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it 'should respond with 422' do
          expect(subject).to have_http_status(422)
        end
      end

      context 'for employee attributes' do
        before do
          json_payload[:employee_attributes].first.delete(:attribute_name)
        end

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it 'should respond with 422' do
          expect(subject).to have_http_status(422)
        end
      end
    end

    context 'with invalid data given' do
      context 'for event' do
        let(:effective_at) { 'not a date' }

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it 'should respond with 422' do
          expect(subject).to have_http_status(422)
        end
      end

      context 'for employee attributes' do
        let(:first_name_attribute_definition) { 'not a def' }

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it 'should respond with 422' do
          expect(subject).to have_http_status(422)
        end
      end

      context 'when invalid value type send' do
        let(:last_name) { ['test'] }

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it { is_expected.to have_http_status(422) }

        context 'response body' do
          before { subject }

          it { expect(response.body).to include 'coercion_error'}
        end
      end
    end
  end

  describe 'POST #create' do
    subject { post :create, json_payload }

    let(:effective_at) { 1.days.from_now.at_beginning_of_day }
    let(:comment) { 'A test comment' }

    let(:first_name) { 'Walter' }
    let(:last_name) { 'Smith' }

    let(:working_place) { create(:working_place, account: Account.current) }

    context 'a new employee' do
      let(:json_payload) do
        {
          type: "employee_event",
          effective_at: effective_at,
          comment: comment,
          event_type: "hired",
          employee: {
            type: 'employee',
            working_place_id: working_place.id
          },
          employee_attributes: [
            {
              type: "employee_attribute",
              attribute_name: first_name_attribute_definition,
              value: first_name
            },
            {
              type: "employee_attribute",
              attribute_name: last_name_attribute_definition,
              value: last_name
            }
          ]
        }
      end

      it { expect { subject }.to change { Employee::Event.count }.by(1) }
      it { expect { subject }.to change { Employee.count }.by(1) }
      it { expect { subject }.to change { Employee::AttributeVersion.count }.by(2) }

      it 'should respond with success' do
        expect(subject).to have_http_status(201)
      end

      it 'should contain event data' do
        expect(subject).to have_http_status(:success)

        expect_json_keys([:id, :type, :effective_at, :comment, :event_type, :employee])
      end

      it 'should have given values' do
        expect(subject).to have_http_status(:success)

        expect_json(comment: json_payload[:comment],
                    event_type: json_payload[:event_type]
                   )
      end

      it 'should contain employee' do
        expect(subject).to have_http_status(:success)

        expect_json_keys('employee', [:id, :type])
      end

      it 'should contain employee attributes' do
        expect(subject).to have_http_status(:success)

        expect_json_keys('employee_attributes.0',
                         [:value, :attribute_name, :id, :type, :order]
                        )
      end

      it 'should create event with multiple pet attributes' do
        json_payload[:employee_attributes] = json_payload[:employee_attributes] +
          pet_multiple_attribute

        expect(subject).to have_http_status(201)
        expect(Employee::AttributeVersion.count).to eq(7)
      end

      it 'should create event when empty array send' do
        json_payload[:employee_attributes] = nil

        expect { subject }.to change { Employee::Event.count }
        expect(subject).to have_http_status(201)
      end

      it 'should create event when employee attributes not send' do
        json_payload.delete(:employee_attributes)

        expect { subject }.to change { Employee.count }.by(1)
        expect(subject).to have_http_status(201)
      end

      context 'json payload for nested value' do
        let(:employee_attributes) {{ attribute_name: attribute_definition, value: value }}
        let(:attribute_definition) { 'address' }
        let(:value) {{ city: 'Wroclaw', country: 'Poland' }}
        before { json_payload[:employee_attributes] = [employee_attributes] }

        it { expect { subject }.to change { Employee::Event.count }.by(1) }
        it { expect { subject }.to change { Employee.count }.by(1) }
        it { expect { subject }.to change { Employee::AttributeVersion.count }.by(1) }

        it { is_expected.to have_http_status(201) }
      end

      it 'should not create event when invalid working_place' do
        json_payload[:employee][:working_place_id] = 'abc'

        expect(subject).to have_http_status(422)
      end

      it 'should not create event when working_place is nil' do
        json_payload[:employee][:working_place_id] = nil

        expect(subject).to have_http_status(422)
      end

      context 'attributes validations' do
        before do
          Account.current.employee_attribute_definitions
            .where(name: 'lastname').first.update!(validation: { presence: true })
        end

        context 'when all params and values are given' do
          it { expect { subject }.to change { Employee::Event.count } }
          it { expect { subject }.to change { Employee.count } }

          it { is_expected.to have_http_status(201) }
        end

        context 'when required param is missing' do
          before { json_payload.delete(:employee_attributes) }

          it { expect { subject }.to_not change { Employee::Event.count } }
          it { expect { subject }.to_not change { Employee.count } }

          it { is_expected.to have_http_status(422) }

          context 'response body' do
            before { subject }

            it { expect(response.body).to include('["missing params: lastname"]') }
          end
        end

        context 'when required param value is set to nil' do
          let(:last_name) { nil }

          it { expect { subject }.to_not change { Employee::Event.count } }
          it { expect { subject }.to_not change { Employee.count } }

          it { is_expected.to have_http_status(422) }

          context 'response body' do
            before { subject }

            it { expect(response.body).to include("can't be blank") }
          end
        end
      end

      it_behaves_like 'Unprocessable Entity on create'
    end

    context 'for an employee that already exist' do
      let(:json_payload) do
        {
          type: "employee_event",
          effective_at: effective_at,
          comment: comment,
          event_type: "change",
          employee: {
            id: employee_id,
            type: 'employee',
          },
          employee_attributes: [
            {
              type: "employee_attribute",
              attribute_name: first_name_attribute_definition,
              value: first_name
            },
            {
              type: "employee_attribute",
              attribute_name: last_name_attribute_definition,
              value: last_name
            }
          ]
        }
      end

      context 'with new content for attributes' do
        it { expect { subject }.to change { Employee::Event.count }.by(1) }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to change { Employee::AttributeVersion.count }.by(2) }

        it 'should respond with success' do
          expect(subject).to have_http_status(201)
        end
      end

      context 'with same content for attributes' do
        let(:first_name) { employee_first_name }
        let(:last_name) { employee_last_name }

        it { expect { subject }.to change { Employee::Event.count }.by(1) }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to change { Employee::AttributeVersion.count }.by(2) }

        it 'should respond with success' do
          expect(subject).to have_http_status(201)
        end
      end

      context 'without content for attributes' do
        before do
          json_payload[:employee_attributes] = []
        end

        it { expect { subject }.to change { Employee::Event.count }.by(1) }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it 'should respond with success' do
          expect(subject).to have_http_status(201)
        end
      end

      context 'with content of attributes to nil' do
        let(:first_name) { nil }

        before do
          json_payload[:employee_attributes].delete_if  do |attr|
            attr[:attribute_name] != first_name_attribute_definition
          end
        end

        it { expect { subject }.to change { Employee::Event.count }.by(1) }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to change { Employee::AttributeVersion.count }.by(1) }

        it 'should respond with success' do
          expect(subject).to have_http_status(201)
        end
      end

      it_behaves_like 'Unprocessable Entity on create'

      context 'with wrong id given' do
        context 'for employee' do
          let(:employee_id) { '123' }

          it { expect { subject }.to_not change { Employee::Event.count } }
          it { expect { subject }.to_not change { Employee.count } }
          it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

          it 'should respond with 404' do
            expect(subject).to have_http_status(404)
          end
        end
      end

      context 'with multiple and system attribute definition' do
        let!(:multiple_system_definition) do
          create(:employee_attribute_definition, :multiple, :system, account: Account.current)
        end
        let(:system_multiple_attribute) do
          [
            {
              type: "employee_attribute",
              attribute_name: multiple_system_definition.name,
              value: first_pet_name,
              order: 1
            },
            {
              type: "employee_attribute",
              attribute_name: multiple_system_definition.name,
              value: second_pet_name,
              order: 2
            }
          ]
        end
        it 'should create event with multiple pet attributes' do
          json_payload[:employee_attributes] = json_payload[:employee_attributes] +
            system_multiple_attribute

          expect(subject).to have_http_status(201)
          expect(Employee::AttributeVersion.count).to eq(7)
        end
      end
    end
  end

  shared_examples 'Unprocessable Entity on update' do
    context 'with invalid data given' do
      context 'for event' do
        let(:effective_at) { 'not a date' }

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it { expect { subject }.to_not change { event.reload.effective_at } }

        it 'should respond with 422' do
          expect(subject).to have_http_status(422)
        end
      end

      context 'for employee attributes' do
        let(:first_name_attribute_definition) { 'not a def' }

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it { expect { subject }.to_not change { first_name_attribute.reload.attribute_name } }

        it 'should respond with 422' do
          expect(subject).to have_http_status(422)
        end
      end
    end

    context 'with two attributes with same name' do
      before do
        attr = json_payload[:employee_attributes].first
        json_payload[:employee_attributes] << attr
      end

      it { expect { subject }.to_not change { Employee::Event.count } }
      it { expect { subject }.to_not change { Employee.count } }
      it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

      it { expect { subject }.to_not change { event.reload.effective_at } }

      it 'should respond with 422' do
        expect(subject).to have_http_status(422)
      end
    end

    context 'with change of attribute definition' do
      let(:first_name_attribute_definition) { last_name_attribute_definition }

      it { expect { subject }.to_not change { Employee::Event.count } }
      it { expect { subject }.to_not change { Employee.count } }
      it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

      it { expect { subject }.to_not change { first_name_attribute.reload.attribute_name } }

      it 'should respond with 422' do
        expect(subject).to have_http_status(422)
      end
    end

    context 'when invalid value type send' do
      let(:last_name) { ['test'] }

      it { expect { subject }.to_not change { Employee::Event.count } }
      it { expect { subject }.to_not change { Employee.count } }
      it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

      it { is_expected.to have_http_status(422) }

      context 'response body' do
        before { subject }

        it { expect(response.body).to include 'coercion_error'}
      end
    end

    context 'with wrong id given' do
      context 'for event' do
        let(:event_id) { SecureRandom.uuid }

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it { expect { subject }.to_not change { event.reload.effective_at } }

        it 'should respond with 404' do
          expect(subject).to have_http_status(404)
        end
      end

      context 'for employee' do
        let(:employee_id) { SecureRandom.uuid }

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it { expect { subject }.to_not change { event.reload.effective_at } }

        it 'should respond with 404' do
          expect(subject).to have_http_status(404)
        end
      end

      context 'for employee attributes' do
        let(:first_name_attribute_id) { SecureRandom.uuid }

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it { expect { subject }.to_not change { first_name_attribute.reload.value } }

        it 'should respond with 404' do
          expect(subject).to have_http_status(404)
        end
      end
    end
  end

  context 'PUT #update' do
    subject { put :update, json_payload }

    let(:json_payload) do
      {
        id: event_id,
        type: "employee_event",
        effective_at: effective_at,
        comment: comment,
        event_type: "hired",
        employee: {
          id: employee_id,
          type: 'employee',
        },
        employee_attributes: [
          {
            id: first_name_attribute_id,
            type: "employee_attribute",
            attribute_name: first_name_attribute_definition,
            value: first_name
          },
          {
            id: last_name_attribute_id,
            type: "employee_attribute",
            attribute_name: last_name_attribute_definition,
            value: last_name
          },
          {
            id: annual_salary_attribute_id,
            type: "employee_attribute",
            attribute_name: annual_salary_attribute_definition,
            value: annual_salary
          }
        ]
      }
    end

    let(:effective_at) { 1.days.from_now.at_beginning_of_day }
    let(:comment) { 'change comment' }

    let(:first_name) { 'Walter' }
    let(:last_name) { 'Smith' }
    let(:annual_salary) { '300' }

    context 'with change in all fields' do
      it { expect { subject }.to_not change { Employee::Event.count } }
      it { expect { subject }.to_not change { Employee.count } }
      it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

      it { expect { subject }.to change { event.reload.comment }.to('change comment') }
      it { expect { subject }.to change { event.reload.effective_at }.to(effective_at) }

      it { expect { subject }.to change { first_name_attribute.reload.value }.to(first_name) }
      it { expect { subject }.to change { last_name_attribute.reload.value }.to(last_name) }
      it { expect { subject }.to change { annual_salary_attribute.reload.value }.to(annual_salary) }

      it 'should respond with success' do
        expect(subject).to have_http_status(204)
      end
    end
    context 'when the user is not an account manager'do
      before { user.account_manager = false }

      context 'and there is a forbidden attribute in the payload' do
        context 'and it has been updated' do
          it 'should respond with error' do
            expect(subject).to have_http_status(403)
            expect(subject.body).to include('Not authorized!')
          end
        end

        context 'and it has not been updated' do
          let(:annual_salary) { employee_annual_salary }

          it { expect { subject }.to_not change { Employee::Event.count } }
          it { expect { subject }.to_not change { Employee.count } }
          it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

          it { expect { subject }.to change { event.reload.comment }.to('change comment') }
          it { expect { subject }.to change { event.reload.effective_at }.to(effective_at) }

          it { expect { subject }.to change { first_name_attribute.reload.value }.to(first_name) }
          it { expect { subject }.to change { last_name_attribute.reload.value }.to(last_name) }
          it { expect { subject }.to_not change { annual_salary_attribute.reload.value } }
        end
      end

      context 'and there is not a forbidden attribute payload' do
        before do
          json_payload[:employee_attributes].delete_if do |attr|
            attr[:attribute_name] ==annual_salary_attribute_definition
          end
          annual_salary_attribute.destroy
        end
        context 'with change in all fields' do
          it { expect { subject }.to_not change { Employee::Event.count } }
          it { expect { subject }.to_not change { Employee.count } }
          it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

          it { expect { subject }.to change { event.reload.comment }.to('change comment') }
          it { expect { subject }.to change { event.reload.effective_at }.to(effective_at) }

          it { expect { subject }.to change { first_name_attribute.reload.value }.to(first_name) }
          it { expect { subject }.to change { last_name_attribute.reload.value }.to(last_name) }

          it 'should respond with success' do
            expect(subject).to have_http_status(204)
          end
        end
      end
    end

    context 'without employee attributes' do
      context 'when not send' do
        before { json_payload[:employee_attributes] = nil }

        it { expect { subject }.to change { event.reload.comment }.to('change comment') }
        it { expect { subject }.to change { event.reload.effective_at }.to(effective_at) }

        it { is_expected.to have_http_status(204) }
      end

      context 'when empty array send' do
        before { json_payload.delete(:employee_attributes) }

        it { expect { subject }.to change { event.reload.comment }.to('change comment') }
        it { expect { subject }.to change { event.reload.effective_at }.to(effective_at) }

        it { is_expected.to have_http_status(204) }
      end
    end

    context 'attributes validations' do
      before do
        Account.current.employee_attribute_definitions
          .where(name: 'lastname').first.update!(validation: { presence: true })
      end

      context 'when all params and values are given' do
        it { expect { subject }.to change { event.reload.comment } }
        it { expect { subject }.to change { last_name_attribute.reload.value } }

        it { is_expected.to have_http_status(204) }
      end

      context 'when required param is missing' do
        before { json_payload.delete(:employee_attributes) }

        it { expect { subject }.to_not change { event.reload.comment } }
        it { expect { subject }.to_not change { last_name_attribute.reload.value } }

        it { is_expected.to have_http_status(422) }

        context 'response body' do
          before { subject }

          it { expect(response.body).to include('["missing params: lastname"]') }
        end
      end

      context 'when required param value is set to nil' do
        let(:last_name) { nil }

        it { expect { subject }.to_not change { event.reload.comment } }
        it { expect { subject }.to_not change { last_name_attribute.reload.value } }

        it { is_expected.to have_http_status(422) }

        context 'response body' do
          before { subject }

          it { expect(response.body).to include("can't be blank") }
        end
      end
    end

    context 'without an attribute than be removed' do
      before do
        json_payload[:employee_attributes].delete_if do |attr|
          attr[:attribute_name] == last_name_attribute_definition
        end
      end

      it { expect { subject }.to_not change { Employee::Event.count } }
      it { expect { subject }.to_not change { Employee.count } }
      it { expect { subject }.to change { Employee::AttributeVersion.count }.by(-1) }

      it { expect { subject }.to change { first_name_attribute.reload.value }.to(first_name) }

      it 'should respond with success' do
        expect(subject).to have_http_status(204)
      end
    end

    context 'with an attribute than be added' do
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
      it { expect { subject }.to change { Employee::AttributeVersion.count}.by(1) }

      it 'should have new attribute version with given value' do
        expect(subject).to have_http_status(:success)

        last_name_attribute = event.reload.employee_attribute_versions.find do |attr|
          attr.attribute_name == last_name_attribute_definition
        end

        expect(last_name_attribute.value).to eql(last_name)
      end

      it 'should respond with success' do
        expect(subject).to have_http_status(204)
      end
    end

    context 'with content of attributes to nil' do
      let(:first_name) { nil }

      it { expect { subject }.to_not change { Employee::Event.count } }
      it { expect { subject }.to_not change { Employee.count } }
      it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

      it 'should set value to nil' do
        expect { subject }.to change { first_name_attribute.reload.value }.to(nil)
      end

      it 'should respond with success' do
        expect(subject).to have_http_status(204)
      end
    end

    it_behaves_like 'Unprocessable Entity on update'

    context 'without all params given' do
      context 'for event' do
        before do
          json_payload.delete(:effective_at)
        end

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it { expect { subject }.to_not change { event.reload.effective_at } }

        it 'should respond with 422' do
          expect(subject).to have_http_status(422)
        end
      end

      context 'for employee attribute name' do
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

        it 'should respond with 422' do
          expect(subject).to have_http_status(422)
        end
      end

      context 'for employee attribute value' do
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

        it 'should respond with 422' do
          expect(subject).to have_http_status(422)
        end
      end
    end

    context 'with new multiple attributes' do
      it 'should update event and create multiple pet attributes' do
        json_payload[:employee_attributes] = json_payload[:employee_attributes] +
          pet_multiple_attribute

        expect(subject).to have_http_status(204)
        expect(Employee::AttributeVersion.count).to eq(5)
        expect(
          employee.reload.employee_attribute_versions.map(&:value)
        ).to include(
          pet_multiple_attribute.first[:value], pet_multiple_attribute.last[:value]
        )
      end

      it 'should update multiple attributes' do
        av = employee.employee_attribute_versions.new(
          attribute_definition: multiple_attribute_definition,
          employee_event_id: event_id,
          multiple: true,
          order: 1
        )
        av.value = "ABC"
        av.save!

        av = employee.employee_attribute_versions.new(
          attribute_definition: multiple_attribute_definition,
          employee_event_id: event_id,
          multiple: true,
          order: 2
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

    context 'reassign working_place' do
      it 'should reassign employee working_place to new one' do
        working_place = create(:working_place, account: Account.current)
        json_payload[:employee][:working_place_id] = working_place.id

        expect(subject).to have_http_status(204)
        expect(Employee.find(employee_id).reload.working_place).to eq(working_place)
      end
    end
  end

  context 'GET #index' do
    before(:each) do
      create_list(:employee_event, 3, employee: employee)
    end

    let(:subject) { get :index, employee_id: employee.id }

    it 'should respond with success' do
      subject

      expect(response).to have_http_status(:success)
      expect_json_sizes(4)
    end

    it 'should have employee events attributes' do
      subject

      expect_json_keys('*', [:effective_at, :event_type, :comment, :employee])
    end

    it 'should have employee' do
      subject

      expect_json_keys('*.employee', [:id, :type])
    end

    it 'should not be visible in context of other account' do
      user = create(:account_user)
      Account.current = user.account

      subject

      expect(response).to have_http_status(404)
    end

    it 'should return 404 when invalid employee id' do
      get :index, employee_id: '12345678-1234-1234-1234-123456789012'

      expect(response).to have_http_status(404)
    end
  end

  context 'GET #show' do
    let(:employee_event) { create(:employee_event, employee: employee) }
    subject { get :show, id: employee_event.id }

    it 'should respond with success' do
      subject

      expect(response).to have_http_status(:success)
    end

    it 'should have employee events attributes' do
      subject

      expect_json_keys([:effective_at, :event_type, :comment, :employee])
    end

    it 'should have employee' do
      subject

      expect_json_keys('employee', [:id, :type])
    end

    it 'should have employee attributes' do
      employee.events.first.employee_attribute_versions.each do |version|
        version.update!(employee_event_id: employee_event.id)
      end
      subject

      expect_json_keys('employee_attributes.0', [:value, :attribute_name, :id, :type, :order])
    end

    it 'should respond with 404 when not user event' do
      user = create(:account_user)
      Account.current = user.account

      subject

      expect(response).to have_http_status(404)
    end

    it 'should respond with 404 when invalid id' do
      get :show, id: '12345678-1234-1234-1234-123456789012'

      expect(response).to have_http_status(404)
    end

    context 'if current_user is not the empoyee requested and not manager' do
      subject { get :show, id: event_id }
      it 'should not include some attributes' do
        subject
        event_attributes = employee.events.first.employee_attribute_versions
        public_attributes = event_attributes.visible_for_other_employees
        not_public_attributes =
          event_attributes
          .joins(:attribute_definition)
          .where
          .not(employee_attribute_definitions:
                { name: ActsAsAttribute::PUBLIC_ATTRIBUTES_FOR_OTHERS }
              )

        public_attributes.each do |attr|
          expect(response.body).to include(attr.attribute_name)
        end

        not_public_attributes.each do |attr|
          expect(response.body).not_to include(attr.attribute_name)
        end
      end
    end
  end
end
