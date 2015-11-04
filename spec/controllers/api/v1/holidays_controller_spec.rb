require 'rails_helper'

RSpec.describe API::V1::HolidaysController, type: :controller do
  include_context 'shared_context_headers'

  let(:account){ create(:account)}
  let(:holiday_policy){ create(:holiday_policy, account: account) }
  let(:not_user_holiday_policy) { create(:holiday_policy) }
  let!(:holiday){ create(:holiday, holiday_policy: holiday_policy) }

  let(:valid_params) do
    {
      "name": "test",
      "type": "holidays",
      "id": holiday.id,
      "date": "12.12.2015",
      "holiday_policy": {
        "id": holiday_policy.id
      }
    }
  end

  let(:missing_params) do
    {
      "id": holiday.id,
      "name": "test",
      "holiday_policy": {
        "id": holiday_policy.id
      },
      "type": "holidays"
    }
  end

  let(:invalid_params) do
    {
      "name": "",
      "holiday_policy": {
        "id": holiday_policy.id
      },
      "type": "holidays",
      "date": "12.12.2015",
      "id": holiday.id
    }
  end

  let(:valid_params_invalid_holiday_policy) do
    {
      "id": holiday.id,
      "name": "test",
      "date": "1.1.2015",
      "holiday_policy": {
        "id": "12345678-1234-1234-1234-123456789012"
      },
      "type": "holidays"
    }
  end

  let(:valid_params_not_authorized_holiday_policy) do
    {
      "name": "test",
      "date": "1.1.2015",
      "holiday_policy": {
        "id": not_user_holiday_policy.id
      },
      "type": "holidays"
    }
  end

  let(:invalid_url_params) do
    {
      "name": "test",
      "type": "holidays",
      "date": "12.12.2015",
      "holiday_policy": {
        "id": holiday_policy.id
      },
      "id": '12345678-abcd-1234-1234-123456789012'
    }
  end

  describe "GET #show" do
    it 'should respond with success when valid params given' do
      get :show, valid_params

      expect(response).to have_http_status(:success)
    end

    it 'should respond with 404 when wrong holiday id' do
      get :show, invalid_url_params

      expect(response).to have_http_status 404
    end

    it 'should respond with 404 when not users holiday given' do
      not_user_holiday = create(:holiday)
      params = { id: not_user_holiday.id, holiday_policy: { id: not_user_holiday.holiday_policy_id }}
      get :show, params

      expect(response).to have_http_status 404
    end
  end

  describe "GET #index" do
    let!(:not_user_holiday) { create(:holiday) }

    it 'should return current users holidays' do
      get :index, holiday_policy_id: holiday_policy.id

      expect(response).to have_http_status(:success)
      expect(response.body).to include holiday.id
      expect(response.body).to_not include not_user_holiday.id

      data = JSON.parse(response.body)
      expect(data.size).to eq 1
    end

    it 'should return default holidays for country Poland' do
      holiday_policy = create(:holiday_policy, :with_country, account: account)

      get :index, holiday_policy_id: holiday_policy.id
      expect(response).to have_http_status(:success)
      data = JSON.parse(response.body)
      expect(data.size).to eq 14
    end

    it 'should return default holidays for country Switzerland and land Zuruch' do
      holiday_policy = create(:holiday_policy, :with_region, account: account)

      get :index, holiday_policy_id: holiday_policy.id
      expect(response).to have_http_status(:success)
      data = JSON.parse(response.body)
      expect(data.size).to eq 10
    end

    it 'should return default holidays for country Poland and custom' do
      holiday_policy = create(:holiday_policy, :with_country, account: account)
      create(:holiday, holiday_policy_id: holiday_policy.id)

      get :index, holiday_policy_id: holiday_policy.id
      expect(response).to have_http_status(:success)
      data = JSON.parse(response.body)
      expect(data.size).to eq 15
    end
  end

  describe "POST #create" do
    context 'valid data and valid holiday policy id' do
      subject { post :create, valid_params }

      it 'should create record when valid holiday_policy_id and data given' do
        expect { subject }.to change { Holiday.count }.by(1)
      end

      it 'should respond with success when valid data given' do
        subject

        expect(response).to have_http_status(:success)
      end
    end

    context 'invalid holiday_policy_id and valid data given' do
      subject { post :create, valid_params_invalid_holiday_policy }

      it 'should not create record when invalid holiday_policy_id and valid data given' do
        expect { subject }.to_not change { Holiday.count }
      end

      it 'shoudl respond with 404 when invalid holiday_policy_id given' do
        subject

        expect(response).to have_http_status 404
      end
    end

    context 'valid data, user not authorized' do
      subject { post :create, valid_params_not_authorized_holiday_policy }

      it 'should not create record when user is not authorized' do
        expect { subject }.to_not change { Holiday.count }
      end

      it 'should respond with 404' do
        subject

        expect(response).to have_http_status 404
      end
    end

    context 'invalid data, valid holiday policy id' do
      subject { post :create, invalid_params }

      it 'should not create record when valid holiday_policy_id and invalid data given' do
        expect { subject }.to_not change { Holiday.count }
      end

      it 'should respond with 422 when invalid data given' do
        subject

        expect(response).to have_http_status 422
      end
    end

    context 'missing params' do
      subject { post :create, missing_params }

      it 'should not create record when valid holiday_policy_id and invalid data given' do
        expect { subject }.to_not change { Holiday.count }
      end

      it 'should respond with 422 when invalid data given' do
        subject

        expect(response).to have_http_status 422
        expect(response.body).to include("missing")
      end
    end
  end

  describe "PUT #update" do
    let!(:holiday){ create(:holiday, holiday_policy: holiday_policy) }

    context 'valid params valid holiday id' do
      subject { put :update, valid_params.merge(id: holiday.id) }

      it 'expect subject to change holiday' do
        expect { subject }.to change { holiday.reload.name }
      end

      it 'expect response to be success' do
        subject

        expect(response).to have_http_status(:success)
      end
    end

    context 'invalid holiday id' do
      subject { put :update, invalid_url_params }

      it 'expect subject to not change holiday' do
        expect { subject }.to_not change { holiday.reload.name }
      end

      it 'expect response to be success' do
        subject

        expect(response).to have_http_status 404
      end
    end

    context 'invalid params' do
      subject { put :update, invalid_params.merge(id: holiday.id) }

      it 'expect subject to not change holiday' do
        expect { subject }.to_not change { holiday.reload.name }
      end

      it 'expect response to have status 422' do
        subject

        expect(response).to have_http_status 422
      end
    end

    context 'missing params' do
      subject { put :update, missing_params }

      it 'should not create record when valid holiday_policy_id and invalid data given' do
        expect { subject }.to_not change { Holiday.count }
      end

      it 'should respond with 422 when invalid data given' do
        subject

        expect(response).to have_http_status 422
        expect(response.body).to include("missing")
      end
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, params }

    context 'when valid id' do
      let!(:holiday) { create(:holiday, holiday_policy: holiday_policy) }
      let(:params) {{ id: holiday.id, holiday_policy: { id: holiday_policy.id }}}

      it 'should delete holiday' do
        expect{ subject }.to change { Holiday.count }.by(-1)
      end

      it 'should have response status 204' do
        subject

        expect(response).to have_http_status 204
      end
    end

    context 'when user do not have access or not exist' do
      let!(:not_user_holiday){ create(:holiday) }
      let(:params) do
        { id: not_user_holiday.id, holiday_policy: { id: not_user_holiday.holiday_policy_id }}
      end

      it 'should not delete holiday' do
        expect{ subject }.to_not change { Holiday.count }
      end

      it 'should have response status 404' do
        subject

        expect(response).to have_http_status 404
      end
    end
  end
end
