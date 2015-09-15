require 'rails_helper'

RSpec.describe API::V1::EmployeesController, type: :controller do
  let(:account) { user.account }
  let(:user) { FactoryGirl.create(:account_user) }

  let(:attribute_definition) {
    FactoryGirl.create(
      :employee_attribute_definition,
      attribute_type: 'String',
      account: account
    )
  }

  let(:employee_uuid) { SecureRandom.uuid }
  let(:event_uuid) { SecureRandom.uuid }
  let(:attribute_uuid) { SecureRandom.uuid }

  let(:json_payload) {
    {
      'data'=> {
        'type' => 'employees',
        'id' => employee_uuid,
        'relationships' => {
          'events' => {
            'data' => [
              {
                'type' => 'employee-events',
                'id' => event_uuid,
                'attributes' => {
                  'event-type' => 'hired',
                  'effective-at' => '2015-09-10T00:00:00.000Z'
                },
                'relationships' => {
                  'employee-attributes': {
                    data: [
                      {
                        'type' => 'employee-attributes',
                        'id' => attribute_uuid,
                        'attributes' => {
                          'value' => 'Fred',
                        },
                        'relationships' => {
                          'attribute-definition' => {
                            'type' => 'employee-attribute-definitions',
                            'id' => "#{attribute_definition.id}"
                          }
                        }
                      }
                    ]
                  }
                }
              }
            ]
          }
        }
      }
    }
  }

  before(:each) do
    Account.current = account
    @request.headers.merge!(
      'CONTENT-TYPE' => 'application/vnd.api+json',
      'ACCEPT' => 'application/vnd.api+json'
    )
  end

  context 'POST #create' do

    it 'should return bad request status if data is not present' do
      post :create, {}

      expect(response).to have_http_status(:bad_request)
    end

    it 'should return bad request status if type is not employees' do
      post :create, { 'data' => { 'type' => 'badtypes' }}

      expect(response).to have_http_status(:bad_request)
    end

    it 'should return conflict status if employee already exists' do
      FactoryGirl.create(:employee, id: employee_uuid, account: account)

      post :create, json_payload

      expect(response).to have_http_status(:conflict)
    end

    it 'create an employee with given uuid' do
      expect {
        post :create, json_payload
      }.to change(account.employees.where(id: employee_uuid), :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it 'create an event with given uuid' do
      expect {
        post :create, json_payload
      }.to change(Employee::Event.where(id: event_uuid), :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it 'create an attribute with given uuid' do
      expect {
        post :create, json_payload
      }.to change(Employee::AttributeVersion.where(id: attribute_uuid), :count).by(1)

      expect(response).to have_http_status(:created)
    end

  end
end
