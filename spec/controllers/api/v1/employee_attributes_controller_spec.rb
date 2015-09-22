require 'rails_helper'

RSpec.describe API::V1::EmployeeAttributesController, type: :controller do
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
      FactoryGirl.create_list(:employee_attribute, 5, employee: employee)
    end

    it 'should respond with success' do
      get :index

      expect(response).to have_http_status(:success)
      expect_json_sizes(data: 5)
    end

    it 'should not be visible in context of other account' do
      user = FactoryGirl.create(:account_user)
      Account.current = user.account

      get :index

      expect(response).to have_http_status(:success)
      expect_json []
    end
  end
end
