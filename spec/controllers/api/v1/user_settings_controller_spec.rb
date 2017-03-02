require 'rails_helper'

RSpec.describe API::V1::UserSettingsController, type: :controller do
  include_examples 'example_authorization',
    resource_name: 'account_user'
  include_context 'shared_context_headers'

  describe 'GET #show' do
    subject { get :show }

    it { is_expected.to have_http_status(200) }

    context 'response body' do
      before { subject }

      it { expect_json(email: user.email, id: user.id, type: 'account_user', locale: nil) }
    end

    context 'when locale is set' do
      before do
        user.update(locale: 'en')
        subject
      end

      it { expect_json(locale: 'en') }
    end

  end

  describe 'PUT #update' do
    let(:email) { 'test@email.com' }
    let(:old_password) { '12344321' }
    let(:password) { '12345678' }
    let(:password_confirmation) { password }
    let(:locale) { nil }
    let(:params) do
      {
        email: email,
        password_params: {
          old_password: old_password,
          password: password,
          password_confirmation: password_confirmation,
          locale: locale
        }
      }
    end

    subject { put :update, params }
    before { user.update(password: '12344321') }

    context 'with valid params' do
      context 'when password not send' do
        before { params.tap { |param| param.delete(:password_params) } }

        it { expect { subject }.to change { user.reload.email } }
        it { expect { subject }.to_not change { user.reload.password_digest } }

        it { is_expected.to have_http_status(204) }
      end

      context 'when password send' do
        it { expect { subject }.to change { user.reload.email } }
        it { expect { subject }.to change { user.reload.password_digest } }

        it { is_expected.to have_http_status(204) }
      end

      context 'when language is set' do
        let(:locale) { 'en' }

        it { expect { subject }.to change { user.reload.locale }.from(nil).to('en') }
        it { is_expected.to have_http_status(204) }
      end

      context 'when language is unset' do
        let(:locale) { nil }

        before { user.update(locale: 'en') }

        it { expect { subject }.to change { user.reload.locale }.from('en').to(nil) }
        it { is_expected.to have_http_status(204) }
      end
    end

    shared_examples 'Missing or Invalid Params' do
      it { expect { subject }.to_not change { user.reload.email } }
      it { expect { subject }.to_not change { user.reload.password_digest } }

      it { is_expected.to have_http_status(422) }
    end

    context 'with invalid params' do
      context 'when invalid email' do
        let(:email) { 'testtest' }

        it_behaves_like 'Missing or Invalid Params'
      end

      context 'when invalid password' do
        let(:password) { 'test' }

        it_behaves_like 'Missing or Invalid Params'
      end

      context 'when old password do not match' do
        let(:old_password) { 'abcd1234' }

        it { expect { subject }.to_not change { user.reload.email } }
        it { expect { subject }.to_not change { user.reload.password_digest } }

        it { is_expected.to have_http_status(403) }
      end

      context 'when password confirmation do not match password' do
        let(:password_confirmation) { 'abcdefgh' }

        it_behaves_like 'Missing or Invalid Params'
      end

      context 'when language is not available' do
        let(:locale) { 'xx' }

        it_behaves_like 'Missing or Invalid Params'
      end

      context 'when params missing' do
        context 'when email is missing' do
          before { params.tap { |param| param.delete(:email) } }

          it_behaves_like 'Missing or Invalid Params'
        end

        context 'when password params are missing' do
          before { params[:password_params].tap { |param| param.delete(:old_password) } }

          it_behaves_like 'Missing or Invalid Params'
        end
      end
    end
  end
end
