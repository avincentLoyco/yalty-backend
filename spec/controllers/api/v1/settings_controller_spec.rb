require 'rails_helper'

RSpec.describe API::V1::SettingsController, type: :controller do
  include_context 'shared_context_headers'

  let(:settings_json) do
    {
      "data": {
        "type": "settings",
        "attributes": {
          "company-name": "My Company",
          "subdomain": "my-company-946",
          "timezone": "Europe/Madrid",
          "default-locale": "en"
        }
      }
    }
  end

  context 'GET #show' do
    it 'should response with success' do
      get :show

      expect(response).to have_http_status(:success)
    end

    it 'should return only current account' do
      get :show

      data = JSON.parse(response.body)
      expect(data.size).to eq(1)
    end
  end

  context 'PUT #update' do
    it "should update" do
      put :update, settings_json
      expect(response).to have_http_status(:success)
    end

    it "should not update when timezone is not valid" do
      settings_json[:data][:attributes][:timezone] = 'abc'

      put :update, settings_json
      expect(response).to have_http_status(422)
    end

    it 'should not update when there is no params' do
      put :update, {}
      expect(response).to have_http_status(400)
    end

    it 'should allow to set Zurich timezone' do
      zurich_timezone = "Europe/Zurich"
      settings_json[:data][:attributes][:timezone] = zurich_timezone

      put :update, settings_json

      expect(response).to have_http_status(:success)
      expect(account.reload.timezone).to eq(zurich_timezone)
    end
  end

  context 'POST #create' do
    it 'should not be routable' do
      expect(:post => "/api/v1/settings").not_to be_routable
    end
  end

  context 'DELETE #delete' do
    it 'should not be routable' do
      expect(:delete => "/api/v1/settings/#{account.id}").not_to be_routable
    end
  end

  context 'PUT #assign-holiday-policy' do
    let(:holiday_policy) { FactoryGirl.create(:holiday_policy, account: account) }

    it 'should assign holiday policy' do
      params = { data: { 'id': holiday_policy.id } }

      put :assign_holiday_policy, params
      expect(response).to have_http_status(:success)
      expect(account.reload.holiday_policy).to eq(holiday_policy)
    end

    it 'should not change assigned policy' do
      params = { data: { 'id': '' } }

      put :assign_holiday_policy, params
      expect(response).to have_http_status(404)
    end

    it 'should return record not found' do
      params = { data: { 'id': 'abc' } }

      put :assign_holiday_policy, params
      expect(response).to have_http_status(404)
    end

  end
end
