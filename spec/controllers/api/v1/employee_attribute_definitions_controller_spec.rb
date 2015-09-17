require 'rails_helper'

RSpec.describe API::V1::EmployeeAttributeDefinitionsController, type: :controller do
  let(:account) { user.account }
  let(:user) { FactoryGirl.create(:account_user) }

  before(:each) do
    Account.current = account
    @request.headers.merge!(
      'CONTENT-TYPE' => 'application/vnd.api+json',
      'ACCEPT' => 'application/vnd.api+json'
    )
  end

  context 'GET /employee-attribute-definitions' do
    before(:each) do
      FactoryGirl.create_list(:employee_attribute_definition, 3, account: account)
    end

    it 'should respond with success' do
      get :index

      expect(response).to have_http_status(:success)
    end
  end
end
