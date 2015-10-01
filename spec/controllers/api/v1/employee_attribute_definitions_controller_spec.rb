require 'rails_helper'

RSpec.describe API::V1::EmployeeAttributeDefinitionsController, type: :controller do
  include_context 'shared_context_headers'
  let(:user) { create(:account_user) }

  context 'GET /employee-attribute-definitions' do
    before(:each) do
      create_list(:employee_attribute_definition, 3, account: account)
    end

    it 'should respond with success' do
      get :index

      expect(response).to have_http_status(:success)
      expect_json_sizes(data: 5)
    end

    it 'should not be visible in context of other account' do
      user = create(:account_user)
      Account.current = user.account

      get :index

      expect(response).to have_http_status(:success)
      expect_json_sizes(data: 2)
    end
  end
end
