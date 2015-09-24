require 'rails_helper'

RSpec.describe API::V1::EmployeeAttributeDefinitionsController, type: :controller do
  include_context 'shared_context_headers'
  let(:user) { FactoryGirl.create(:account_user) }

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
