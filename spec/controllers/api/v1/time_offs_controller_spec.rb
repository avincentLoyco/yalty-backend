require 'rails_helper'

RSpec.describe API::V1::TimeOffsController, type: :controller do
  include_context 'shared_context_headers'

  let(:time_off_category) { create(:time_off_category, account: account) }
  let!(:time_off) { create(:time_off, time_off_category_id: time_off_category.id) }

  describe 'GET #show' do
    subject { get :show, id: id }

    context 'with valid id' do
      let(:id) { time_off.id }

      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it { expect_json_keys(:id, :type, :start_time, :end_time) }
      end
    end

    context 'with invalid id' do
      context 'time off with given id does not exist' do
        let(:id) { 'abc' }

        it { is_expected.to have_http_status(404) }
      end

      context 'time off belongs to other account' do
        before { Account.current = create(:account) }
        let(:id) { time_off.id }

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe 'PUT #update' do
    let(:id) { time_off.id }
    let(:start_time) { Time.now }
    let(:end_time) { start_time + 1.week }
    let(:params) do
      {
        id: id,
        type: 'time_off',
        start_time: start_time,
        end_time: end_time,
      }
    end

    subject { put :update, params }

    context 'with valid params' do
      it { expect { subject }.to change { time_off.reload.start_time } }
      it { expect { subject }.to change { time_off.reload.end_time } }

      it { is_expected.to have_http_status(204) }
    end

    context 'with invalid params' do
      context 'params are missing' do
        before { params.delete(:start_time) }

        it { expect { subject }.to_not change { time_off.reload.start_time } }
        it { expect { subject }.to_not change { time_off.reload.end_time } }

        it { is_expected.to have_http_status(422) }
      end

      context 'params do not pass validation' do
        let(:end_time) { start_time - 1.week }

        it { expect { subject }.to_not change { time_off.reload.start_time } }
        it { expect { subject }.to_not change { time_off.reload.end_time } }

        it { is_expected.to have_http_status(422) }
      end

      context 'invalid id given' do
        let(:id) { 'abc' }

        it { expect { subject }.to_not change { time_off.reload.start_time } }
        it { expect { subject }.to_not change { time_off.reload.end_time } }

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, id: id }
    let(:id) { time_off.id }

    context 'with valid data' do
      let(:id) { time_off.id }

      it { expect { subject }.to change { TimeOff.count }.by(-1) }
      it { is_expected.to have_http_status(204) }
    end

    context 'with invalid data' do
      context 'with invalid id' do
        let(:id) { 'abc' }

        it { expect { subject }.to_not change { TimeOff.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'with not account id' do
        before { Account.current = create(:account) }

        it { expect { subject }.to_not change { TimeOff.count } }
        it { is_expected.to have_http_status(404) }
      end
    end
  end
end
