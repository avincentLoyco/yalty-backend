require 'rails_helper'

RSpec.describe API::V1::HolidayPoliciesController, type: :controller do

  context 'GET /holiday_policies' do
    before(:each) do
      FactoryGirl.create_list(:holiday_policy, 3, account: account)
    end

    it 'should respond with success' do
      get :index

      expect(response).to have_http_status(:success)
    end

    it 'should not be visible in context of other account' do
      user = FactoryGirl.create(:account_user)
      Account.current = user.account

      get :index

      expect(response).to have_http_status(:success)
      expect_json_sizes(data: 0)
    end
  end
end
