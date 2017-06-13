require 'rails_helper'

RSpec.describe Auth::UsersController, type: :controller do
  let(:user) { create(:account_user, :with_reset_password_token) }
  before { Account.current = user.account }

  describe 'POST #reset_password' do
    subject { post :reset_password, email: email }
    let(:email) { user.email }

    context 'with valid params' do
      it { expect { subject }.to change { user.reload.reset_password_token } }
      it { expect { subject }.to change { ActionMailer::Base.deliveries.count }.by(1) }

      context 'when user doesn\'t have related employee' do
        before do
          user.employee = nil
          user.save(validate: false)
        end

        it { expect { subject }.to change { user.reload.reset_password_token } }
      end

      it { is_expected.to have_http_status(204) }
    end

    context 'with invalid params' do
      context 'when invali email' do
        let(:email) { 'abc' }

        it { expect { subject }.to_not change { user.reload.reset_password_token } }
        it { expect { subject }.to_not change { ActionMailer::Base.deliveries.count } }

        it { is_expected.to have_http_status(404) }
      end

      context 'when email is missing' do
        subject { post :reset_password }

        it { expect { subject }.to_not change { user.reload.reset_password_token } }
        it { expect { subject }.to_not change { ActionMailer::Base.deliveries.count } }

        it { is_expected.to have_http_status(422) }
      end

      context 'when current account not set' do
        before { Account.current = nil }

        it { expect { subject }.to_not change { user.reload.reset_password_token } }
        it { expect { subject }.to_not change { ActionMailer::Base.deliveries.count } }

        it { is_expected.to have_http_status(401) }
      end
    end
  end

  describe 'PUT #new_password' do
    let(:reset_password_token) { user.reset_password_token }
    let(:password) { '12345678' }
    let(:password_confirmation) { password }
    let(:params) do
      {
        reset_password_token: reset_password_token,
        password: password,
        password_confirmation: password_confirmation
      }
    end

    subject { put :new_password, params }

    context 'with valid params' do
      it { expect { subject }.to change { user.reload.password_digest } }
      it { is_expected.to have_http_status(204) }
    end

    context 'with invalid params' do
      context 'when token invalid' do
        let(:reset_password_token) { 'abc' }

        it { expect { subject }.to_not change { user.reload.password_digest } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when param is missing' do
        context 'when reset_password_token is missing' do
          before { params.tap { |param| params.delete(:reset_password_token) } }

          it { expect { subject }.to_not change { user.reload.password_digest } }
          it { is_expected.to have_http_status(422) }
        end

        context 'when password is missing' do
          before { params.tap { |param| params.delete(:password) } }

          it { expect { subject }.to_not change { user.reload.password_digest } }
          it { is_expected.to have_http_status(422) }
        end

        context 'when password confirmation is missing' do
          before { params.tap { |param| params.delete(:password_confirmation) } }

          it { expect { subject }.to_not change { user.reload.password_digest } }
          it { is_expected.to have_http_status(422) }
        end
      end

      context 'when password do not match confirmation' do
        let(:password_confirmation) { 'abcddcba' }

        it { expect { subject }.to_not change { user.reload.password_digest } }
        it { is_expected.to have_http_status(422) }
      end

      context 'when password do not match validations' do
        let(:password) { 'ba' }

        it { expect { subject }.to_not change { user.reload.password_digest } }
        it { is_expected.to have_http_status(422) }
      end
    end
  end
end
