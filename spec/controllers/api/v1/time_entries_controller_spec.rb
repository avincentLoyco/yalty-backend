require 'rails_helper'

RSpec.describe  API::V1::TimeEntriesController, type: :controller do
  include_examples 'example_authorization',
    resource_name: 'presence_policy'
  include_context 'shared_context_headers'

  let(:presence_policy) { create(:presence_policy, account: account) }
  let(:presence_day) { create(:presence_day, presence_policy: presence_policy) }
  let!(:time_entry) { create(:time_entry, presence_day: presence_day) }

  describe 'GET #show' do
    subject { get :show, id: id }
    let(:id) { time_entry.id }

    context 'with valid params' do
      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it { expect_json_keys(:id, :type, :end_time, :start_time) }
        it { expect(response.body).to include time_entry.id }
      end
    end

    context 'with invalid params' do
      context 'time entry belongs to other account' do
        before { Account.current = create(:account) }

        it { is_expected.to have_http_status(404) }
      end

      context 'invalid id' do
        let(:id) { 'abc' }

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe 'GET #index' do
    subject { get :index, presence_day_id: presence_day.id }
    let!(:other_user_entry) { create(:time_entry) }
    let!(:second_time_entry) do
      create(:time_entry, start_time: '18:00', 'end_time': '19:00', presence_day: presence_day)
    end

    context "account's schedule" do
      before { subject }

      it { is_expected.to have_http_status(200) }
      it { expect(response.body).to include(second_time_entry.id, time_entry.id) }
      it { expect(response.body).to_not include(other_user_entry.id) }
    end

    context 'other accoun presence day' do
      before { Account.current = create(:account) }

      it { is_expected.to have_http_status(404) }
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, id: id }
    let(:id) { time_entry.id }

    context 'with valid data' do
      it { expect { subject }.to change { TimeEntry.count }.by(-1) }
      it { is_expected.to have_http_status(204) }
    end

    context 'with invalid data' do
      context 'invalid id' do
        let(:id) { 'abc' }

        it { expect { subject }.to_not change { TimeEntry.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'time entry belong to other account' do
        before { Account.current = create(:account) }

        it { expect { subject }.to_not change { TimeEntry.count } }
        it { is_expected.to have_http_status(404) }
      end
    end
  end
end
