require 'rails_helper'

RSpec.describe API::V1::WorkingPlacesController, type: :controller do
  include_context 'shared_context_headers'

  let(:working_place) { FactoryGirl.create(:working_place) }

  context 'GET /working_places' do
    before(:each) do
      FactoryGirl.create_list(:working_place, 3, account: account)
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
      expect_json []
    end
  end
end
