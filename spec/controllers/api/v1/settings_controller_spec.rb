require 'rails_helper'

RSpec.describe API::V1::SettingsController, type: :controller do
  include_examples 'example_authorization',
    resource_name: 'account'
  include_context 'shared_context_headers'

  describe 'GET #show' do
    subject { get :show }

    it { is_expected.to have_http_status(200) }

    context 'response body' do
      before { subject }

      it { expect_json(
          subdomain: account.subdomain,
          company_name: account.company_name,
          default_locale: account.default_locale,
          id: account.id,
          type: 'account',
          timezone: account.timezone
        )
      }
    end
  end

  describe 'without user GET #show' do
    before(:each) do
      Account::User.current = nil
    end

    it 'should return company name and locale when is account' do
      get :show
      data = JSON.parse(response.body)
      expect(response).to have_http_status(200)
      expect(data).to include('company_name')
      expect(data).to include('default_locale')
      expect(data).to_not include('subdomain')
      expect(data).to_not include('id')
      expect(data['company_name']).to eq(Account.current.company_name)
    end

    it 'should return 401 when account is not present' do
      Account.current = nil

      get :show
      expect(response).to have_http_status(401)
    end
  end

  describe 'PUT #update' do
    let(:holiday_policy) { create(:holiday_policy, account: account) }
    let(:holiday_policy_id) { holiday_policy.id }
    let(:company_name) { 'My Company' }
    let(:timezone) { 'Europe/Madrid' }
    let(:subdomain) { Account.current.subdomain }
    let(:holiday_policy_json) do
      {
        id: holiday_policy_id
      }
    end

    let(:settings_json) do
      {
        type: 'settings',
        company_name: company_name,
        subdomain: subdomain,
        timezone: timezone,
        default_locale: 'en',
        holiday_policy: holiday_policy_json
      }
    end

    subject { put :update, settings_json }

    context 'with valid data' do
      it { expect { subject }.to change { account.reload.company_name } }
      it { expect { subject }.to change { account.reload.holiday_policy_id } }

      it { is_expected.to have_http_status(204) }

      context 'with zurich timezone' do
        let(:timezone) { 'Europe/Zurich' }

        it { expect { subject }.to change { account.reload.timezone }.to('Europe/Zurich') }

        it { is_expected.to have_http_status(204) }
      end

      context 'with nil with holiday policy' do
        before { account.update(holiday_policy_id: holiday_policy.id) }
        let(:holiday_policy_json) { nil }

        it { expect { subject }.to change { account.reload.holiday_policy_id }.to(nil) }

        it { is_expected.to have_http_status(204) }
      end

      context 'subdomain' do
        context 'when subdomain does not change' do
          it { expect { subject }.to_not change { Account.current.reload.subdomain } }

          it { is_expected. to have_http_status(204) }
        end

        context 'when subdomain change' do
          let(:redirect_uri) { 'http://yalty.test/setup'}
          let(:client) { FactoryGirl.create(:oauth_client, redirect_uri: redirect_uri) }
          let(:subdomain) { 'new-subdomain' }

          before(:each) do
            ENV['YALTY_OAUTH_ID'] = client.uid
            ENV['YALTY_OAUTH_SECRET'] = client.secret
          end

          it { expect { subject }.to change { Account.current.reload.subdomain } }
          it { is_expected. to have_http_status(301) }

          context 'response' do
            before { subject }

            it { expect_json(redirect_uri: regex("^http://#{subdomain}.yalty.test/setup")) }
          end
        end
      end
    end

    context 'with invalid data' do
      context 'with invalid timezone' do
        let(:timezone) { 'abc' }

        it { expect { subject }.to_not change { account.reload.company_name } }
        it { expect { subject }.to_not change { account.reload.holiday_policy_id } }

        it { is_expected.to have_http_status(422) }
      end

      context 'with missing params' do
        let(:missing_params_json) { settings_json.tap { |attr| attr.delete(:company_name) } }
        subject { put :update, missing_params_json }

        it { expect { subject }.to_not change { account.reload.company_name } }
        it { expect { subject }.to_not change { account.reload.holiday_policy_id } }

        it { is_expected.to have_http_status(422) }
      end

      context 'holiday policy' do
        context 'with holiday policy that do not belong to account' do
          let(:other_account_policy) { create(:holiday_policy) }
          let(:holiday_policy_id) { other_account_policy.id }

          it { expect { subject }.to_not change { account.reload.company_name } }
          it { expect { subject }.to_not change { account.reload.holiday_policy_id } }

          it { is_expected.to have_http_status(404) }
        end

        context 'with empty holiday policy' do
          let(:holiday_policy_json) { {} }

          it { is_expected.to have_http_status(422) }
        end

        context 'with invalid holdiay policy id' do
          let(:holiday_policy_id) { '12' }

          it { is_expected.to have_http_status(404) }
        end

        context 'with empty holiday policy id' do
          let(:holiday_policy_id) { '' }

          it { is_expected.to have_http_status(422) }
        end
      end
    end
  end
end
