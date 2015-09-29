require 'rails_helper'

RSpec.describe API::V1::WorkingPlacesController, type: :controller do
  include_examples 'example_crud_resources',
    resource_name: 'working_place'
  include_examples 'example_relationships_employees',
    resource_name: 'working_place'

  let!(:working_place) { FactoryGirl.create(:working_place, account_id: account.id) }
  let(:working_place_json) do
    {
      "data": {
        "type": "working-places",
        "attributes": {
          "name": "Nice office"
        }
      }
    }
  end

  context 'POST /working_places' do
    it 'should create working_place for current account' do
      post :create, working_place_json

      expect(response).to have_http_status(:success)
      expect(account.working_places.size).to eq(2)
      expect(account.working_places.map(&:name)).to include working_place_json[:data][:attributes][:name]
    end
  end
end
