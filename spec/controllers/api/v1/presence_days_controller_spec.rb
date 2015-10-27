require 'rails_helper'

RSpec.describe API::V1::PresenceDaysController, type: :controller do
  include_context 'shared_context_headers'

  describe 'GET #show' do
    let(:presence_policy) { create(:presence_policy, account: account) }
    let(:presence_day) { create(:presence_day, presence_policy: presence_policy) }
    subject { get :show, params }

    context 'valid data' do
      let(:params) {{ id: presence_day.id, presence_policy_id: presence_policy.id }}

      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it { expect_json_keys([:order, :id, :hours]) }
      end
    end

    context 'invalid data' do
      context 'invalid id' do
        let(:params) {{ id: '2', presence_policy_id: presence_policy.id }}

        it { is_expected.to have_http_status(404) }
      end

      context 'invalid presence policy id' do
        let(:params) {{ id: presence_day.id, presence_policy_id: '1' }}

        it { is_expected.to have_http_status(404) }
      end

      context 'not user presence day' do
        let(:params) {{ id: presence_day.id, presence_policy_id: presence_policy.id }}
        before(:each) do
          user = create(:account_user)
          Account.current = user.account
        end

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe 'GET #index' do
    let(:presence_policy) { create(:presence_policy, account: account) }
    let!(:presence_days) { create_list(:presence_day, 2, presence_policy: presence_policy) }
    subject { get :index, presence_policy_id: presence_policy.id }

    context 'account presence days' do
      before { subject }

      it { expect_json_sizes(2) }
      it { is_expected.to have_http_status(200) }
    end

    context 'not accounts presence policy' do
      before(:each) do
        user = create(:account_user)
        Account.current = user.account
      end

      it { is_expected.to have_http_status(404) }
    end

    context 'invalid presence policy id' do
      subject { get :index, presence_policy_id: '1' }

      it { is_expected.to have_http_status(404) }
    end
  end
end
