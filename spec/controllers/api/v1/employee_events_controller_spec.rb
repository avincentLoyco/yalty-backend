require 'rails_helper'

RSpec.describe API::V1::EmployeeEventsController, type: :controller do
  let(:account) { user.account }
  let(:user) { FactoryGirl.create(:account_user) }
  let(:employee) { FactoryGirl.create(:employee, account: account) }

  let(:attribute_definition) {
    FactoryGirl.create(
      :employee_attribute_definition,
      attribute_type: 'String',
      account: account
    )
  }

  before(:each) do
    Account.current = account
    @request.headers.merge!(
      'CONTENT-TYPE' => 'application/vnd.api+json',
      'ACCEPT' => 'application/vnd.api+json'
    )
  end

  context 'POST #create' do
    let(:employee_uuid) { employee.id }
    let(:event_uuid) { SecureRandom.uuid }
    let(:attribute_uuid) { SecureRandom.uuid }
    let(:attribute_value) { 'Fred' }

    let(:json_payload) do
      {
        'data'=> {
          'type' => 'employee-events',
          'id' => event_uuid,
          'attributes' => {
            'event-type' => 'hired',
            'effective-at' => '2015-09-10T00:00:00.000Z',
            'comment' => 'A comment'
          },
          'relationships' => {
            'employee' => {
              'data' => {
                'type' => 'employees',
                'id' => employee_uuid,
              }
            },
            'employee-attributes' => {
              'data' => [
                {
                  'type' => 'employee-attributes',
                  'id' => attribute_uuid,
                  'attributes' => {
                    'value' => attribute_value,
                  },
                  'relationships' => {
                    'attribute-definition' => {
                      'data' => {
                        'type' => 'employee-attribute-definitions',
                        'id' => "#{attribute_definition.id}"
                      }
                    }
                  }
                }
              ]
            }
          }
        }
      }
    end

    it 'should return bad request status if data is not present' do
      post :create, {}

      expect(response).to have_http_status(:bad_request)
    end

    it 'should return bad request status if type is not employee-events' do
      post :create, { 'data' => { 'type' => 'badtypes' }}

      expect(response).to have_http_status(:bad_request)
    end

    it 'should return conflict status if event already exists' do
      FactoryGirl.create(:employee_event, id: event_uuid, employee: employee)

      post :create, json_payload

      expect(response).to have_http_status(:conflict)
    end

    it 'create an event with given uuid' do
      expect {
        post :create, json_payload
      }.to change(Employee::Event.where(id: event_uuid), :count).by(1)

      expect(response).to have_http_status(:no_content)
    end

    it 'create an event with given type' do
      post :create, json_payload

      event = Employee::Event.where(id: event_uuid).first!

      expect(event.event_type).to_not be_nil
      expect(event.event_type).to eql('hired')
    end

    it 'create an event with given effective date' do
      post :create, json_payload

      event = Employee::Event.where(id: event_uuid).first!

      expect(event.effective_at).to_not be_nil
      expect(event.effective_at).to match(Date.new(2015, 9, 10))
    end

    it 'create an event with given comment' do
      post :create, json_payload

      event = Employee::Event.where(id: event_uuid).first!

      expect(event.comment).to_not be_nil
      expect(event.comment).to eql('A comment')
    end

    it 'create an attribute with given uuid' do
      expect {
        post :create, json_payload
      }.to change(Employee::AttributeVersion.where(id: attribute_uuid), :count).by(1)

      expect(response).to have_http_status(:no_content)
    end

    it 'create an attribute with given value' do
      post :create, json_payload

      attribute = Employee::AttributeVersion.where(id: attribute_uuid).first!

      expect(attribute.value).to_not be_nil
      expect(attribute.value).to eql(attribute_value)
    end

    it 'load sample json payload' do
      json_payload = JSON.parse(File.read(Rails.root.join('spec', 'fixtures', 'files', 'employee_event_create.json')))

      FactoryGirl.create(
        :employee,
        id: json_payload['data']['relationships']['employee']['data']['id'],
        account: account
      )

      json_payload['data']['relationships']['employee-attributes']['data'].each do |attr|
        FactoryGirl.create(
          :employee_attribute_definition,
          id: attr['relationships']['attribute-definition']['data']['id'],
          attribute_type: 'String',
          account: account
        )
      end

      post :create, json_payload

      expect(response).to have_http_status(:no_content)
    end
  end

  context 'GET /employee-events' do
    before(:each) do
      FactoryGirl.create_list(:employee_event, 3) # in another account
      FactoryGirl.create_list(:employee_event, 3, employee: employee)
    end

    it 'should respond with success' do
      get :index

      expect(response).to have_http_status(:success)
    end

    it 'should be scoped to current account' do
      get :index

      expect_json_types(data: :array_of_objects)
      expect_json_sizes(data: 3)
    end

    it 'should have effective-at attribute' do
      get :index

      expect_json_keys('data.*.attributes', :'effective-at')
    end

    it 'should have event-type attribute' do
      get :index

      expect_json_keys('data.*.attributes', :'event-type')
    end

    it 'should have comment attribute' do
      get :index

      expect_json_keys('data.*.attributes', :comment)
    end

    it 'should have employee' do
      get :index

      expect_json_keys('data.*.relationships', :'employee')
    end

    it 'should have employee-attributes' do
      get :index

      expect_json_keys('data.*.relationships', :'employee-attributes')
    end
  end
end
