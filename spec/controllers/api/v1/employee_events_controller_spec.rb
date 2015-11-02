require 'rails_helper'

RSpec.describe API::V1::EmployeeEventsController, type: :controller do
  include_context 'shared_context_headers'

  let(:user) { create(:account_user) }

  let!(:employee) do
    create(:employee, :with_attributes,
      account: account,
      event: {
        event_type: 'hired',
        effective_at: 2.days.from_now.at_beginning_of_day
      },
      employee_attributes: {
        firstname: employee_first_name,
        lastname: employee_last_name
      }
    )
  end
  let(:employee_id) { employee.id }
  let(:employee_first_name) { 'John' }
  let(:employee_last_name) { 'Doe' }

  let!(:event) { employee.events.where(event_type: 'hired').first! }
  let(:event_id) { event.id }

  let(:first_name_attribute_definition) { 'firstname'}
  let(:first_name_attribute) do
    event.employee_attribute_versions.find do |attr|
      attr.attribute_name == 'firstname'
    end
  end
  let(:first_name_attribute_id) { first_name_attribute.id }

  let(:last_name_attribute_definition) { 'lastname'}
  let(:last_name_attribute) do
    event.employee_attribute_versions.find do |attr|
      attr.attribute_name == 'lastname'
    end
  end
  let(:last_name_attribute_id) { last_name_attribute.id }

  shared_examples 'Unprocessable Entity on create' do
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
        let(:first_name_attribute_definition) { 'not a def' }

        it { expect { subject }.to_not change { Employee::Event.count } }
        it { expect { subject }.to_not change { Employee.count } }
        it { expect { subject }.to_not change { Employee::AttributeVersion.count } }

        it 'should respond with 422' do
          expect(subject).to have_http_status(422)
        end
      end
    end
  end

  describe 'POST #create' do
    subject { post :create, json_payload }

    let(:effective_at) { 1.days.from_now.at_beginning_of_day.as_json }
    let(:comment) { 'A test comment' }

    let(:first_name) { 'Walter' }
    let(:last_name) { 'Smith' }

    context 'a new employee' do
      let(:json_payload) do
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

        expect_json_keys('employee.employee_attributes.0',
                         [:value, :attribute_name, :id, :type]
                        )
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
        attr = json_payload[:employee][:employee_attributes].first
        json_payload[:employee][:employee_attributes] << attr
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
            }
          ]
        }
      }
    end

    let(:effective_at) { 1.days.from_now.at_beginning_of_day.as_json }
    let(:comment) { 'change comment' }

    let(:first_name) { 'Walter' }
    let(:last_name) { 'Smith' }

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

    context 'without an attribute than be removed' do
      before do
        json_payload[:employee][:employee_attributes].delete_if do |attr|
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

        json_payload[:employee][:employee_attributes].each do |attr|
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
          attr_json = json_payload[:employee][:employee_attributes].find do |attr|
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
          attr_json = json_payload[:employee][:employee_attributes].find do |attr|
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
