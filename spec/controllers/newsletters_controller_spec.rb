require 'rails_helper'

RSpec.describe NewslettersController, type: :controller do
  describe 'POST #create' do
    let(:params) do
      {
        email: 'test@example.com',
        name: 'Test User',
        language: 'fr'
      }
    end

    subject { post :create, params }

    context 'with valid params' do
      it { is_expected.to have_http_status(:no_content) }
    end

    context 'with invalid params' do
      context 'when params are missing' do
        shared_examples 'Missing param' do
          it { is_expected.to have_http_status(422) }
        end

        context 'when email not send' do
          before { params.tap { |param| param.delete(:email) } }

          it_behaves_like 'Missing param'
        end

        context 'when name not send' do
          before { params.tap { |param| param.delete(:name) } }

          it_behaves_like 'Missing param'
        end
      end
    end
  end
end
