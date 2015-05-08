require 'rails_helper'

RSpec.describe AccountsController, type: :controller do

  describe 'POST' do
    let(:params) { Hash(account: { company_name: 'The Company' }, user: { email: 'test@test.com', password: '12345678' }) }

    it 'should create account' do
      expect do
        post :create, params
      end.to change(Account, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it 'should create user' do
      expect do
        post :create, params
      end.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
    end

  end

end
