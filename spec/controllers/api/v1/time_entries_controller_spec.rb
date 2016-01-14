require 'rails_helper'

RSpec.describe  API::V1::TimeEntriesController, type: :controller do
  include_examples 'example_authorization',
    resource_name: 'presence_policy'
  include_context 'shared_context_headers'

  let(:presence_policy) { create(:presence_policy, account: account) }
  let!(:presence_day) { create(:presence_day, presence_policy: presence_policy, order: 1) }
  let!(:next_presence_day) { create(:presence_day, presence_policy: presence_policy, order: 2) }
  let!(:time_entry) { create(:time_entry, presence_day: presence_day) }

  describe 'GET #show' do
    subject { get :show, id: id }
    let(:id) { time_entry.id }

    context 'with valid params' do
      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it { expect_json_keys(:id, :type, :end_time, :start_time, :presence_day) }
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

  describe 'POST #create' do
    subject { post :create, params }
    let(:presence_day_id) { presence_day.id }
    let(:start_time) { '20:00' }
    let(:end_time) { '22:00' }
    let(:params) do
      {
        start_time: start_time,
        end_time: end_time,
        type: 'time_entry',
        presence_day: {
          id: presence_day_id,
          type: 'presence_day'
        }
      }
    end

    context 'with valid params' do
      before { presence_day.reload.update_minutes! }
      it { expect { subject }.to change { TimeEntry.count }.by(1) }
      it { expect { subject }.to change { presence_day.reload.time_entries.count }.by(1) }
      it { expect { subject }.to change { presence_day.reload.minutes }.by(120) }
      it { is_expected.to have_http_status(201) }

      context 'response body' do
        before { subject }

        it { expect_json_keys(:id, :type, :start_time, :end_time, :presence_day) }
      end
    end

    context 'with invalid params' do
      context 'when presence day id is invalid' do
        let(:presence_day_id) { 'abc' }

        it { expect { subject }.to_not change { TimeEntry.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when params are missing' do
        before { params.delete(:start_time) }

        it { expect { subject }.to_not change { TimeEntry.count } }
        it { is_expected.to have_http_status(422) }
      end

      context 'when data do not pass validation' do
        let(:start_time) { '00:00' }
        let(:end_time) { '12:00' }

        before do
          TimeEntry.create(
            start_time: '22:00', end_time: '2:00', presence_day: next_presence_day
          )
        end

        it { expect { subject }.to_not change { TimeEntry.count } }
        it { expect { subject }.to_not change { presence_day.reload.time_entries.count } }
        it { expect { subject }.to_not change { presence_day.reload.minutes } }

        it { is_expected.to have_http_status(422) }

        context 'response body' do
          before { subject }

          it { expect(response.body).to include 'time_entries can not overlap' }
        end
      end
    end
  end

  describe 'PUT #update' do
    subject { put :update, params }
    let(:presence_day_id) { presence_day.id }
    let(:start_time) { '20:00' }
    let(:end_time) { '22:00' }
    let(:id) { time_entry.id }
    let(:params) do
      {
        id: id,
        start_time: start_time,
        end_time: end_time,
        type: 'time_entry',
        presence_day: {
          id: presence_day_id,
          type: 'presence_day'
        }
      }
    end

    context 'with valid params' do
      it { expect { subject }.to change { time_entry.reload.start_time } }
      it { expect { subject }.to change { presence_day.reload.minutes } }
      it { is_expected.to have_http_status(204) }
    end

    context 'with invalid params' do
      context 'when time entry id is invalid' do
        let(:id) { 'abc' }

        it { expect { subject }.to_not change { time_entry.reload.start_time } }
        it { expect { subject }.to_not change { presence_day.reload.minutes } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when data do not pass validation' do
        before do
          TimeEntry.create(start_time: start_time, end_time: end_time, presence_day: presence_day)
        end

        it { expect { subject }.to_not change { time_entry.reload.start_time } }
        it { expect { subject }.to_not change { presence_day.reload.minutes } }
        it { is_expected.to have_http_status(422) }
      end

      context 'when params are missing' do
        before { params.delete(:start_time) }

        it { expect { subject }.to_not change { time_entry.reload.start_time } }
        it { expect { subject }.to_not change { presence_day.reload.minutes } }
        it { is_expected.to have_http_status(422) }
      end
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, id: id }
    let(:id) { time_entry.id }

    context 'with valid data' do
      it { expect { subject }.to change { TimeEntry.count }.by(-1) }
      it { is_expected.to have_http_status(204) }

      context 'presence day minutes' do
        before { subject }

        it { expect(presence_day.reload.minutes).to eq(0) }
      end
    end

    context 'with invalid data' do
      context 'invalid id' do
        let(:id) { 'abc' }

        it { expect { subject }.to_not change { TimeEntry.count } }
        it { expect { subject }.to_not change { presence_day.reload.minutes } }
        it { is_expected.to have_http_status(404) }
      end

      context 'time entry belong to other account' do
        before { Account.current = create(:account) }

        it { expect { subject }.to_not change { TimeEntry.count } }
        it { expect { subject }.to_not change { presence_day.reload.minutes } }
        it { is_expected.to have_http_status(404) }
      end
    end
  end
end
