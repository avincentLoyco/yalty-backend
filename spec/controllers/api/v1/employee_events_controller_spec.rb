require 'rails_helper'

RSpec.describe API::V1::EmployeeEventsController, type: :controller do
  include_context 'shared_context_headers'

  let(:user) { create(:account_user) }
  let!(:employee) { create(:employee, :with_attributes, account: account) }
  
  describe 'POST #create' do
    let(:valid_event_params) do
    {
      type: "employee_event",
      effective_at: "12.12.2015",
      comment: "test",
      event_type: "hired"
    }
  end
  let(:valid_attributes) do
    {
      employee_attributes: [
        {
          attribute_name: "lastname",
          value: "smith",
          type: "employee_attribute"
        },
        {
          attribute_name: "firstname",
          value: "john",
          type: "employee_attribute"
        }
      ]
    }
  end
  let(:existing_attributes) do
    {
      employee_attributes: [
        {
          id: employee.employee_attribute_versions.first.id,
          value: 'smith',
          attribute_name: employee.employee_attribute_versions.first.attribute_definition.name
        },
        {
          id: employee.employee_attribute_versions.last.id,
          value: 'smith',
          attribute_name: employee.employee_attribute_versions.last.attribute_definition.name
        }
      ]
    }
  end
  let(:remove_attribute) do
    {
      employee_attributes: [
        {
          id: employee.employee_attribute_versions.first.id,
          value: nil,
          attribute_name: employee.employee_attribute_versions.first.attribute_definition.name
        }
      ]
    }
  end
  let!(:new_employee_json) do
    valid_event_params.deep_merge(employee: { type: 'employee'}.merge(valid_attributes))
  end
  let(:existing_employee_json) do
    valid_event_params.deep_merge(employee: { type: 'employee', id: employee.id }
      .merge(valid_attributes))
  end
  let(:existing_employee_params_json) do
    valid_event_params.deep_merge(employee: { type: 'employee', id: employee.id }
      .merge(existing_attributes))
  end
  let(:existing_employee_remove_param_json) do
    valid_event_params.deep_merge(employee: { type: 'employee', id: employee.id }
      .merge(remove_attribute))
  end
  let(:missing_event_params) { new_employee_json.tap { |json| json.delete(:event_type) }}
  let(:invalid_event_params) { new_employee_json.merge(event_type: 'test')}
  let(:missing_attribute_params) do
    new_employee_json.tap { |json| json[:employee][:employee_attributes].first.delete(:attribute_name) }
  end
  let(:invalid_attribute_params) do
    new_employee_json.deep_merge(employee: { employee_attributes: [{ type: 'test' }] })
  end
  let(:invalid_employee_id_params) { new_employee_json.deep_merge(employee: { id: '1' } ) }
  let(:invalid_attribute_id_params) do
    new_employee_json.deep_merge(employee: { employee_attributes: [{ 
      id: '1', 
      value: 'ABC', 
      attribute_name: 'test' }] 
    })
  end

    context 'valid data' do
      context 'new employee' do
        subject { post :create, new_employee_json }
        it { expect { subject }.to change { Employee::Event.count }.by(1) }
        it { expect { subject }.to change { Employee.count }.by(1) }
        it { expect { subject }.to change { Employee::AttributeVersion.count }.by(2) }

        context 'response' do
          it 'should respond with success' do
            subject

            expect(response).to have_http_status(201)
          end

          it 'should contain event data' do
            subject

            expect_json_keys([:id, :type, :effective_at, :comment, :event_type, :employee])
          end

          it 'should have given values' do
            subject

            expect_json(comment: new_employee_json[:comment],
                        event_type: new_employee_json[:event_type]
            )
          end

          it 'should contain employee' do
            subject

            expect_json_keys('employee', [:id, :type])
          end

          it 'should contain employee attributes' do
            expect(response.body).to eq 'heee'

            expect_json_keys('employee.employee_attributes.0',
              [:value, :attribute_name, :id, :type]
            )
          end
        end
      end

      context 'employee already exist' do
        subject { post :create, existing_employee_json }

        context 'new attributes send' do
          it { expect { subject }.to change { Employee::Event.count }.by(1) }
          it { expect { subject }.to_not change { Employee.count } }
          it { expect { subject }.to change { Employee::AttributeVersion.count }.by(2) }

          it 'should respond with success' do
            subject

            expect(response).to have_http_status(201)
          end
        end

        context 'already added attributes send' do
          subject { post :create, existing_employee_remove_param_json }
          before { employee.employee_attribute_versions.first.update!(value: 'test') }

          it { expect { subject }.to change { Employee::Event.count }.by(1) }
          it { expect { subject }.to_not change { Employee.count } }
          it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

          it 'changes value to nil'  do 
            expect { subject }.to change { employee.employee_attribute_versions.first.reload.value }.to(nil) 
          end

          it 'should respond with success' do
            subject

            expect(response).to have_http_status(201)
          end
        end
      end
    end

    context 'invalid data' do
      context 'not all params given' do
        context 'for event' do
          subject { post :create, missing_event_params }

          it { expect { subject }.to_not change { Employee::Event.count } }
          it { expect { subject }.to_not change { Employee.count } }
          it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

          it 'should respond with 422' do
            subject

            expect(response).to have_http_status(422)
          end
        end

        context 'for employee attributes' do
          subject { post :create, missing_attribute_params }

          it { expect { subject }.to_not change { Employee::Event.count } }
          it { expect { subject }.to_not change { Employee.count } }
          it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

          it 'should respond with 422' do
            subject

            expect(response).to have_http_status(422)
          end
        end
      end

      context 'invalid data given' do
        context 'for event' do
          subject { post :create, invalid_event_params }

          it { expect { subject }.to_not change { Employee::Event.count } }
          it { expect { subject }.to_not change { Employee.count } }
          it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

          it 'should respond with 422' do
            subject

            expect(response).to have_http_status(422)
          end
        end

        context 'for employee attributes' do
          subject { post :create, invalid_attribute_params }

          it { expect { subject }.to_not change { Employee::Event.count } }
          it { expect { subject }.to_not change { Employee.count } }
          it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

          it 'should respond with 422' do
            subject

            expect(response).to have_http_status(422)
          end
        end
      end

      context 'wrong id given' do
        context 'for employee' do
          subject { post :create, invalid_employee_id_params }

          it { expect { subject }.to_not change { Employee::Event.count } }
          it { expect { subject }.to_not change { Employee.count } }
          it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

          it 'should respond with 404' do
            subject

            expect(response).to have_http_status(404)
          end
        end

        context 'for employee attribute' do
          subject { post :create, invalid_attribute_id_params }

          it { expect { subject }.to_not change { Employee::Event.count } }
          it { expect { subject }.to_not change { Employee.count } }
          it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

          it 'should respond with 404' do
            subject

            expect(response).to have_http_status(404)
          end
        end
      end

      context 'exitisting attribute send with value other than nil' do
        subject { post :create, existing_employee_params_json }
        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it 'should respond with 422' do
          subject

          expect(response).to have_http_status(422)
        end
      end
    end
  end

  context 'PUT #update' do
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
      base_json.tap { |json| json[:employee][:employee_attributes].first.delete(:attribute_name) }
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

    it 'should have employee attributes' do
      subject

      expect_json_keys('*.employee.employee_attributes.0', [:value, :attribute_name, :id, :type])
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
