require 'rails_helper'

RSpec.describe API::V1::EmployeeEventsController, type: :controller do
  include_context 'shared_context_headers'

  let(:user) { create(:account_user) }
  let!(:employee) { create(:employee, :with_attributes, account: account) }
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
          type: employee.employee_attribute_versions.first.attribute_definition.name
        },
        {
          id: employee.employee_attribute_versions.last.id,
          value: 'smith',
          type: employee.employee_attribute_versions.last.attribute_definition.name
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
          type: employee.employee_attribute_versions.first.attribute_definition.name
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
    new_employee_json.deep_merge(employee: { employee_attributes: [{ id: '1' }] })
  end

  describe 'POST #create' do
    context 'valid data' do
      context 'new employee' do
        subject { post :create, new_employee_json }

        it 'should create an event' do
          expect { subject }.to change { Employee::Event.count }.by(1)
        end

        it 'should create an employee' do
          expect { subject }.to change { Employee.count }.by(1)
        end

        it 'should create attribute versions' do
          expect { subject }.to change { Employee::AttributeVersion.count }.by(2)
        end

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
            subject

            expect_json_keys('employee.employee_attributes.0',
              [:value, :attribute_name, :id, :type]
            )
          end
        end
      end

      context 'employee already exist' do
        subject { post :create, existing_employee_json }

        context 'new attributes send' do
          it 'should create an event' do
            expect { subject }.to change { Employee::Event.count }.by(1)
          end

          it 'should not create new employee' do
            expect { subject }.to_not change { Employee.count }
          end

          it 'should create attributes' do
            expect { subject }.to change { Employee::AttributeVersion.count }.by(2)
          end

          it 'should respond with success' do
            subject

            expect(response).to have_http_status(201)
          end
        end

        context 'already added attributes send' do
          context 'add attribute with value' do
            subject { post :create, existing_employee_params_json }

            it 'should create an event' do
              expect { subject }.to change { Employee::Event.count }.by(1)
            end

            it 'should not create new employee' do
              expect { subject }.to_not change { Employee.count }
            end

            it 'should create attributes' do
              expect { subject }.to change { Employee::AttributeVersion.count }.by(1)
            end

            it 'should have two attributes with the same definition' do
              subject

              expect(employee.employee_attribute_versions.first.attribute_definition)
                .to eq(employee.employee_attribute_versions.last.attribute_definition)
            end

            it 'should respond with success' do
              subject

              expect(response).to have_http_status(201)
            end
          end

          context 'add attribute with null value' do
            subject { post :create, existing_employee_remove_param_json }

            it 'should create an event' do
              expect { subject }.to change { Employee::Event.count }.by(1)
            end

            it 'should not create new employee' do
              expect { subject }.to_not change { Employee.count }
            end

            it 'should remove attribute' do
              expect { subject }.to change { Employee::AttributeVersion.count }.by(-1)
            end

            it 'should respond with success' do
              subject

              expect(response).to have_http_status(201)
            end
          end
        end
      end
    end

    context 'invalid data' do
      context 'not all params given' do
        context 'for event' do
          subject { post :create, missing_event_params }

          it 'should not create event' do
            expect { subject }.to_not change { Employee::Event.count }
          end

          it 'should not create employee' do
            expect { subject }.to_not change { Employee.count }
          end

          it 'should not create attributes' do
            expect { subject }.to_not change { Employee::AttributeVersion.count }
          end

          it 'should respond with 422' do
            subject

            expect(response).to have_http_status(422)
          end
        end

        context 'for employee attributes' do
          subject { post :create, missing_attribute_params }

          it 'should not create event' do
            expect { subject }.to_not change {  Employee::Event.count }
          end

          it 'should not create employee' do
            expect { subject }.to_not change { Employee.count }
          end

          it 'should not create attributes' do
            expect { subject }.to_not change { Employee::AttributeVersion.count }
          end

          it 'should respond with 422' do
            subject

            expect(response).to have_http_status(422)
          end
        end
      end

      context 'invalid data given' do
        context 'for event' do
          subject { post :create, invalid_event_params }

          it 'should not create event' do
            expect { subject }.to_not change { Employee::Event.count }
          end

          it 'should not create employee' do
            expect { subject }.to_not change { Employee.count }
          end

          it 'should not create attributes' do
            expect { subject }.to_not change { Employee::AttributeVersion.count }
          end

          it 'should respond with 422' do
            subject

            expect(response).to have_http_status(422)
          end
        end

        context 'for employee attributes' do
          subject { post :create, invalid_attribute_params }

          it 'should not create event' do
            expect { subject }.to_not change { Employee::Event.count }
          end

          it 'should not create employee' do
            expect { subject }.to_not change { Employee.count }
          end

          it 'should not create attributes' do
            expect { subject }.to_not change { Employee::AttributeVersion.count }
          end

          it 'should respond with 422' do
            subject

            expect(response).to have_http_status(422)
          end
        end
      end

      context 'wrong id given' do
        context 'for employee' do
          subject { post :create, invalid_employee_id_params }

          it 'should not create event' do
            expect { subject }.to_not change { Employee::Event.count }
          end

          it 'should not create employee' do
            expect { subject }.to_not change { Employee.count }
          end

          it 'should not create attributes' do
            expect { subject }.to_not change { Employee::AttributeVersion.count }
          end

          it 'should respond with 404' do
            subject

            expect(response).to have_http_status(404)
          end
        end

        context 'for employee attribute' do
          subject { post :create, invalid_attribute_id_params }

          it 'should not create event' do
            expect { subject }.to_not change { Employee::Event.count }
          end

          it 'should not create employee' do
            expect { subject }.to_not change { Employee.count }
          end

          it 'should not create attributes' do
            expect { subject }.to_not change { Employee::AttributeVersion.count }
          end

          it 'should respond with 404' do
            subject

            expect(response).to have_http_status(404)
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
