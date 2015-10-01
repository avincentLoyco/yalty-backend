require 'rails_helper'

RSpec.describe API::V1::HolidaysController, type: :controller do
  include_context 'shared_context_headers'

  let(:account){ create(:account)}
  let(:holiday_policy){ create(:holiday_policy, account: account) }

  describe "GET #show" do
    let!(:holiday){ create(:holiday, holiday_policy: holiday_policy) }

    it 'should respond with success when valid params given' do
      params = { "id" => holiday.id }
      get :show, params
      expect(response).to have_http_status(:success)
    end

    it 'should respond with 404 when wrong holiday id' do
      params = { id: '12345678-1234-1234-1234-123456789012' }
      get :show, params

      expect(response.status).to eq 404
    end

    it 'should respond with 404 when not users holiday given' do
      holiday_without_holiday_policy = create(:holiday)
      params = { id: holiday_without_holiday_policy.id }
      get :show, params

      expect(response.status).to eq 404
    end
  end

  describe "GET #index" do
    let!(:holiday_without_holiday_policy) { create(:holiday) }
    let!(:holidays_with_holiday_policy) do
      create_list(:holiday, 3, holiday_policy: holiday_policy)
    end

    it 'should return current users holidays' do
      get :index

      expect(response).to have_http_status(:success)
      expect(response.body).to include holiday_policy.holidays.first.id
      expect(response.body).to_not include holiday_without_holiday_policy.id

      data = JSON.parse(response.body)['data']
      expect(data.size).to eq 3
    end
  end

  describe "POST #create" do

    context 'valid data and valid holiday policy id' do
      let(:valid_params_with_holiday_policy) do
        {
          "data": {
            "attributes": {
              "name": "test",
              "date": "1.1.2015",
              "holiday-policy-id": holiday_policy.id
            },
            "type": "holidays"
          }
        }
      end

      subject { post :create, valid_params_with_holiday_policy }

      it 'should create record when valid holiday_policy_id and data given' do
        expect { subject }.to change { Holiday.count }.by(1)
      end

      it 'should respond with success when valid data given' do
        subject

        expect(response).to have_http_status(:success)
      end
    end

    context 'invalid holiday_policy_id and valid data given' do
      let(:valid_params_invalid_holiday_policy) do
        {
          "data": {
            "attributes": {
              "name": "test",
              "date": "1.1.2015",
              "holiday-policy-id": "12345678-1234-1234-1234-123456789012"
            },
            "type": "holidays"
          }
        }
      end

      subject { post :create, valid_params_invalid_holiday_policy }

      it 'should not create record when invalid holiday_policy_id and valid data given' do
        expect { subject }.to_not change { Holiday.count }
      end

      it 'shoudl respond with 404 when invalid holiday_policy_id given' do
        subject

        expect(response.status).to eq 404
      end
    end

    context 'valid data, user not authorized' do
      let(:second_account) { create(:account) }
      let(:holiday_policy_without_holiday) do
        create(:holiday_policy, account: second_account)
      end
      let(:valid_params_not_authorized_holiday_policy) do
        {
          "data": {
            "attributes": {
              "name": "test",
              "date": "1.1.2015",
              "holiday-policy-id": holiday_policy_without_holiday.id
            },
            "type": "holidays"
          }
        }
      end

      subject { post :create, valid_params_not_authorized_holiday_policy }

      it 'should not create record when user is not authorized' do
        expect { subject }.to_not change { Holiday.count }
      end

      it 'should respond with 403' do
        subject

        expect(response.status).to eq 403
      end
    end

    context 'invalid data, valid holiday policy id' do
      let(:invalid_params_valid_holiday_policy) do
        {
          "data": {
            "attributes": {
              "date": "9.9.1993",
              "holiday-policy-id": holiday_policy.id
            },
            "type": "holidays"
          }
        }
      end

      subject { post :create, invalid_params_valid_holiday_policy }

      it 'should not create record when valid holiday_policy_id and invalid data given' do
        expect { subject }.to_not change { Holiday.count }
      end

      it 'should respond with 422 when invalid data given' do
        subject

        expect(response.status).to eq 422
      end
    end
  end

  describe "PUT #update" do
    let!(:holiday){ create(:holiday, holiday_policy: holiday_policy) }

    let(:valid_params) do
      {
        "data": {
          "attributes": {
            "name": "test"
          },
          "type": "holidays",
          "id": holiday.id
        }
      }
    end

    let(:invalid_params) do
      {
        "data": {
          "attributes": {
            "name": ""
          },
          "type": "holidays",
          "id": holiday.id
        }
      }
    end

    let(:invalid_url_params) do
      {
        "data": {
          "attributes": {
            "name": "test"
          },
          "type": "holidays",
          "id": '12345678-abcd-1234-1234-123456789012'
        }
      }
    end

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
      subject { put :update, invalid_url_params.merge(id: '12345678-abcd-1234-1234-123456789012') }

      it 'expect subject to not change holiday' do
        expect { subject }.to_not change { holiday.reload.name }
      end

      it 'expect response to be success' do
        subject

        expect(response.status).to eq 404
      end
    end

    context 'invalid params' do
      subject { put :update, invalid_params.merge(id: holiday.id) }

      it 'expect subject to not change holiday' do
        expect { subject }.to_not change { holiday.reload.name }
      end

      it 'expect response to be success' do
        subject

        expect(response.status).to eq 422
      end
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, params }

    context 'when valid id' do
      let!(:holiday){ create(:holiday, holiday_policy: holiday_policy) }
      let(:params) {{ id: holiday.id }}

      it 'should delete holiday' do
        expect{ subject }.to change { Holiday.count }.by(-1)
      end

      it 'should have response status 204' do
        subject

        expect(response.status).to eq 204
      end
    end

    context 'when user do not have access or not exist' do
      let!(:holiday_without_policy){ create(:holiday) }
      let(:params) {{ id: holiday_without_policy.id }}

      it 'should not delete holiday' do
        expect{ subject }.to_not change { Holiday.count }
      end

      it 'should have response status 404' do
        subject

        expect(response.status).to eq 404
      end
    end
  end
end
