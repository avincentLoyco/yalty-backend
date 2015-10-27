require 'rails_helper'

RSpec.describe API::V1::EmployeeEventsController, type: :controller do
  include_context 'shared_context_headers'

  let(:user) { create(:account_user) }

  let(:employee_first_name) { 'John' }
  let(:employee_last_name) { 'Doe' }
  let!(:employee) do
    create(:employee, :with_attributes,
      account: account,
      event: {
        effective_at: 2.days.from_now.at_beginning_of_day
      },
      employee_attributes: {
        firstname: employee_first_name,
        lastname: employee_last_name
      }
    )
  end

  describe 'POST #create' do
    subject { post :create, json_payload }

    let(:effective_at) { 1.days.from_now.at_beginning_of_day.as_json }
    let(:comment) { 'A test comment' }

    let(:employee_id) { employee.id.to_s }

    let(:first_name) { 'Walter' }
    let(:first_name_attribute_definition) { 'firstname'}
    let(:last_name) { 'Smith' }
    let(:last_name_attribute_definition) { 'lastname'}

    let(:new_employee_json) do
      {
        type: "employee_event",
        effective_at: effective_at,
        comment: comment,
        event_type: "hired",
        employee: {
          type: 'employee',
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
      }
    end

    let(:existing_employee_json) do
      {
        type: "employee_event",
        effective_at: effective_at,
        comment: comment,
        event_type: "hired",
        employee: {
          type: 'employee',
          id: employee_id,
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
      }
    end

    shared_examples 'Unprocessable Entity' do
      context 'with two attributes with same name' do
        before do
          attr = json_payload[:employee][:employee_attributes].first
          json_payload[:employee][:employee_attributes] << attr
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
            json_payload[:employee][:employee_attributes].first.delete(:attribute_name)
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
          let(:first_name_attribute_definition) { 'not a def'}

          it { expect { subject }.to_not change { Employee::Event.count } }
          it { expect { subject }.to_not change { Employee.count } }
          it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

          it 'should respond with 422' do
            expect(subject).to have_http_status(422)
          end
        end
      end
    end

    context 'a new employee' do
      let(:json_payload) { new_employee_json }

      it { expect { subject }.to change { Employee::Event.count }.by(1) }
      it { expect { subject }.to change { Employee.count }.by(1) }
      it { expect { subject }.to change { Employee::AttributeVersion.count }.by(2) }

      it 'should respond with success' do
        expect(subject).to have_http_status(201)
      end

      it 'should contain event data' do
        expect(subject).to be_success

        expect_json_keys([:id, :type, :effective_at, :comment, :event_type, :employee])
      end

      it 'should have given values' do
        expect(subject).to be_success

        expect_json(comment: json_payload[:comment],
                    event_type: json_payload[:event_type]
                   )
      end

      it 'should contain employee' do
        expect(subject).to be_success

        expect_json_keys('employee', [:id, :type])
      end

      it 'should contain employee attributes' do
        expect(subject).to be_success

        expect_json_keys('employee.employee_attributes.0',
                         [:value, :attribute_name, :id, :type]
                        )
      end

      it_behaves_like 'Unprocessable Entity'
    end

    context 'for an employee that already exist' do
      let(:json_payload) { existing_employee_json }

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
          json_payload[:employee][:employee_attributes] = []
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
          json_payload[:employee][:employee_attributes].delete_if  do |attr|
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

      it_behaves_like 'Unprocessable Entity'

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
    end
  end

  context '#update' do
    let(:employee) { create(:employee, :with_attributes, account: account) }
    let(:event) { employee.events.first }
    let(:first_employee_attribute) { employee.employee_attribute_versions.first }
    let(:second_employee_attribute) { employee.employee_attribute_versions.last }
    let(:base_json) do
      {
        "type": "employee_event",
        "id": event.id,
        "effective_at": event.effective_at,
        "comment": event.comment,
        "event_type": event.event_type,
        "employee": {
          "type": "employee",
          "id": employee.id,
          "employee_attributes": [
            {
              "id": first_employee_attribute.id,
              "type": "employee_attribute",
              "value": first_employee_attribute.data.value,
              "attribute_name": first_employee_attribute.attribute_definition.name
            },
            {
              "id": second_employee_attribute.id,
              "type": "employee_attribute",
              "value": second_employee_attribute.data.value,
              "attribute_name": second_employee_attribute.attribute_definition.name
            }
          ]
        }
      }
    end
    let(:update_event_json) { base_json.merge(comment: 'test') }
    let(:update_attribute_json) do
      base_json.deep_merge(employee: { employee_attributes: [
        { value: 'test', id: first_employee_attribute.id },
        { value: 'test2', id: second_employee_attribute.id }
      ]})
    end
    let(:update_attribute_and_event_params) { update_attribute_json.merge(comment: 'test') }
    let(:invalid_event_id) { base_json.merge(id: '1') }
    let(:invalid_employee_id) { base_json.deep_merge(employee: { id: '1' } ) }
    let(:missing_event_params) { base_json.tap { |json| json.delete(:effective_at) } }
    let(:missing_attribute_params) do
      base_json.tap { |json| json[:employee][:employee_attributes].first.delete(:value) }
    end
    let(:invalid_event_params) { base_json.merge(event_type: 'test')}
    let(:invalid_attribute_params) do
      base_json.deep_merge(employee: { employee_attributes: [{ value: '' }] })
    end
    let(:invalid_attribute_id) do base_json.deep_merge(employee: {
        employee_attributes: [ {
          id: '1',
          value: 'test'
        }]
      })
    end
    let(:json_without_attribute) do
      base_json.deep_merge(employee: { employee_attributes: [
        {
          "id": first_employee_attribute.id,
          "value": first_employee_attribute.data.value
        }
      ]})
    end
    let(:update_single_event_json) { update_event_json.except(:employee) }

    context 'PUT' do
      context 'valid data' do
        context 'event data update' do
          subject { put :update, update_event_json }

          it { expect { subject }.to change { event.reload.comment }.to('test') }
          it { expect { subject }.to_not change { employee.reload.employee_attribute_versions } }
          it { expect { subject }.to_not change { first_employee_attribute.reload.value } }
          it { expect { subject }.to_not change { second_employee_attribute.reload.value } }

          it 'should respond with success' do
            subject

            expect(response).to have_http_status(204)
          end
        end

        context 'employee attribute data update' do
          subject { put :update, update_attribute_json }

          it { expect { subject }.to change { first_employee_attribute.reload.value } }
          it { expect { subject }.to change { second_employee_attribute.reload.value } }
          it { expect { subject }.to_not change { employee } }
          it { expect { subject }.to_not change { event } }

          it 'should respond with success' do
            subject

            expect(response).to have_http_status(204)
          end
        end

        context 'employee and event update' do
          subject { put :update, update_attribute_and_event_params }

          it { expect { subject }.to change { first_employee_attribute.reload.value  } }
          it { expect { subject }.to change { second_employee_attribute.reload.value  } }
          it { expect { subject }.to_not change { employee } }
          it { expect { subject }.to change { event.reload.comment } }

          it 'should respond with success' do
            subject

            expect(response).to have_http_status(204)
          end
        end

        context 'attribute without one attribute send' do
          subject { put :update, json_without_attribute }

          it { expect { subject }.to_not change { employee } }
          it { expect { subject }.to_not change { event } }
          it { expect { subject }.to change { Employee::AttributeVersion.count}.by(-1) }

          it 'should respond with success' do
            subject

            expect(response).to have_http_status(204)
          end
        end
      end

      context 'invalid data' do
        context 'invalid event id' do
          subject { put :update, invalid_event_id }

          it { expect { subject }.to_not change { employee } }
          it { expect { subject }.to_not change { event } }
          it { expect { subject }.to_not change { first_employee_attribute.reload.value } }
          it { expect { subject }.to_not change { second_employee_attribute.reload.value } }

          it 'should repsond with 404' do
            subject

            expect(response).to have_http_status(404)
          end
        end

        context 'invalid employee id' do
          subject { put :update, invalid_employee_id }

          it { expect { subject }.to_not change { employee } }
          it { expect { subject }.to_not change { event } }
          it { expect { subject }.to_not change { first_employee_attribute.reload.value } }
          it { expect { subject }.to_not change { second_employee_attribute.reload.value } }

          it 'should repsond with 404' do
            subject

            expect(response).to have_http_status(404)
          end
        end

        context 'invalid attribute id' do
          subject { put :update, invalid_attribute_id }

          it { expect { subject }.to_not change { employee } }
          it { expect { subject }.to_not change { event } }
          it { expect { subject }.to_not change { first_employee_attribute.reload.value } }
          it { expect { subject }.to_not change { second_employee_attribute.reload.value } }

          it 'should repsond with 404' do
            subject

            expect(response).to have_http_status(404)
          end
        end

        context 'parameters are missing' do
          context 'event params are missing' do
            subject { put :update, missing_event_params }

            it { expect { subject }.to_not change { employee } }
            it { expect { subject }.to_not change { event } }
            it { expect { subject }.to_not change { first_employee_attribute.reload.value } }
            it { expect { subject }.to_not change { second_employee_attribute.reload.value } }

            it 'should repsond with 422' do
              subject

              expect(response).to have_http_status(422)
            end
          end

          context 'employee attribute params are missing' do
            subject { put :update, missing_attribute_params }

            it { expect { subject }.to_not change { employee } }
            it { expect { subject }.to_not change { event } }
            it { expect { subject }.to_not change { first_employee_attribute.reload.value } }
            it { expect { subject }.to_not change { second_employee_attribute.reload.value } }

            it 'should repsond with 422' do
              subject

              expect(response).to have_http_status(422)
            end
          end
        end

        context 'data do not pass validation' do
          context 'event data do not pass validation' do
            subject { put :update, invalid_event_params }

            it { expect { subject }.to_not change { employee } }
            it { expect { subject }.to_not change { event } }
            it { expect { subject }.to_not change { first_employee_attribute.reload.value } }
            it { expect { subject }.to_not change { second_employee_attribute.reload.value } }

            it 'should repsond with 404' do
              subject

              expect(response).to have_http_status(422)
            end
          end

          context 'employee attribute data do not pass validation' do
            subject { put :update, invalid_attribute_params }

            it { expect { subject }.to_not change { employee } }
            it { expect { subject }.to_not change { event } }
            it { expect { subject }.to_not change { first_employee_attribute.reload.value } }
            it { expect { subject }.to_not change { second_employee_attribute.reload.value } }

            it 'should repsond with 404' do
              subject

              expect(response).to have_http_status(422)
            end
          end
        end
      end
    end

    context 'PATCH' do
      context 'event data update' do
        context 'with all data json' do
          subject { patch :update, update_event_json }

          it { expect { subject }.to change { event.reload.comment }.to('test') }
          it { expect { subject }.to_not change { employee.reload.employee_attribute_versions } }
          it { expect { subject }.to_not change { first_employee_attribute.reload.value } }
          it { expect { subject }.to_not change { second_employee_attribute.reload.value } }

          it 'should respond with success' do
            subject

            expect(response).to have_http_status(204)
          end
        end

        context 'with event data only' do
          subject { patch :update, update_single_event_json }

          it { expect { subject }.to change { event.reload.comment }.to('test') }
          it 'should respond with success' do
            subject

            expect(response).to have_http_status(204)
          end
        end
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
      employee.employee_attribute_versions.each do |version|
        version.update!(employee_event_id: employee_event.id)
      end
      subject

      expect_json_keys('employee.employee_attributes.0', [:value, :attribute_name, :id, :type])
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
  end
end
