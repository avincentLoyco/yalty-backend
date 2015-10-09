require 'rails_helper'

RSpec.describe API::V1::EmployeeAttributeDefinitionsController, type: :controller do
  include_context 'shared_context_headers'

  context 'GET #index' do
    before(:each) do
      create_list(:employee_attribute_definition, 3, account: account)
    end

    it 'should respond with success' do
      get :index

      expect(response).to have_http_status(:success)
      data = JSON.parse(response.body)
      expect(data.size).to eq(5)
    end

    it 'should not be visible in context of other account' do
      user = create(:account_user)
      Account.current = user.account

      get :index

      expect(response).to have_http_status(:success)
      data = JSON.parse(response.body)
      expect(data.size).to eq(2)
    end
  end

  context 'GET #show' do
    let(:attribute) { create(:employee_attribute_definition, account: account)}

    it 'should response with success' do
      get :show, { id: attribute.id }

      expect(response).to have_http_status(:success)
      data = JSON.parse(response.body)
      expect(data['id']).to eq(attribute.id)
    end
  end

  context 'DELETE #destroy' do
    let!(:attribute) { create(:employee_attribute_definition, account: account)}

    it 'should delete proper resources' do
      delete :destroy, id: attribute.id

      expect(response).to have_http_status(:success)
    end

    it 'should change resource number' do
      expect { delete :destroy, id: attribute.id }
        .to change { Employee::AttributeDefinition.count }.by(-1)
    end

    it 'should not delete system resource' do
      attribute.update(system: true)
      delete :destroy, id: attribute.id

      expect(response).to have_http_status(423)
    end

    it 'should not be routable without id' do
      expect(:delete => "/api/v1/employee_attribute_definitions").not_to be_routable
    end
  end

  context 'POST #create' do
    let(:params) do
      {
        name: Faker::Lorem.word,
        label: Faker::Lorem.word,
        attribute_type: 'String',
        system: false,
      }
    end

    it 'should respond with success' do
      post :create, params

      expect(response).to have_http_status(:success)
    end

    it 'should create new resource' do
      post :create, params

      data = JSON.parse response.body
      expect(response).to have_http_status(:success)
      expect(data['name']).to eq params[:name]
    end
  end

  context 'PUT #update' do
    let!(:attribute) { create(:employee_attribute_definition, account: account)}
    let(:params) do
      {
        name: Faker::Lorem.word,
        label: Faker::Lorem.word,
        attribute_type: 'String',
        system: false,
        id: attribute.id,
      }
    end

    it 'should update attribute definition' do
      put :update, params
      expect(response).to have_http_status(:success)
      expect(attribute.reload.name).to eq(params[:name])
    end
  end

  context 'Gate #rules' do
    let!(:attribute) { create(:employee_attribute_definition, account: account)}
    let(:invalid_post) do
      {
        label: Faker::Lorem.word,
      }
    end
    let(:invalid_put) do
      {
        id: attribute.id,
        label: Faker::Lorem.word,
        attribute_type: 'String',
        system: false,
      }
    end
    let(:valid_patch) do
      {
        id: attribute.id,
        name: Faker::Lorem.word,
      }
    end

    it 'not valid post params' do
      post :create, invalid_post
      expect(response).to have_http_status(422)
    end

    it 'not valid put params' do
      put :update, invalid_put
      expect(response).to have_http_status(422)
    end

    it 'valid patch params' do
      patch :update, valid_patch
      expect(response).to have_http_status(204)
    end
  end
end
