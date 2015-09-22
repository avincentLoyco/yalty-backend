require 'rails_helper'

RSpec.describe API::V1::SettingsController, type: :controller do
  let(:account) { user.account }
  let(:user) { FactoryGirl.create(:account_user) }

  before(:each) do
    Account.current = account
    @request.headers.merge!(
      'CONTENT-TYPE' => 'application/vnd.api+json',
      'ACCEPT' => 'application/vnd.api+json'
    )
  end

  context 'GET #index' do
    it 'should response with success' do
      get :index

      expect(response).to have_http_status(:success)
    end

    it 'should return only current account' do
      get :index

      data = JSON.parse(response.body)
      expect(data.size).to eq(1)
    end
  end

  context 'PUT #update' do
  end
end
