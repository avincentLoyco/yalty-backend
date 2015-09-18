require 'rails_helper'

RSpec.describe API::V1::EmployeeEventsController, type: :controller do
  let(:account) { user.account }
  let(:user) { FactoryGirl.create(:account_user) }
  let(:employee) { FactoryGirl.create(:employee, account: account) }

  before(:each) do
    Account.current = account
    @request.headers.merge!(
      'CONTENT-TYPE' => 'application/vnd.api+json',
      'ACCEPT' => 'application/vnd.api+json'
    )
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
