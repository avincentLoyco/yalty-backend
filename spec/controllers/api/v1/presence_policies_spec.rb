require 'rails_helper'

RSpec.describe API::V1::PresencePoliciesController, type: :controller do
  include_context 'shared_context_headers'

  describe 'GET #show' do
    let(:presence_policy) { create(:presence_policy, account: account) }

    context 'valid data' do
      it 'should respond with success' do
        get :show, id: presence_policy.id

        expect(response).to have_http_status(200)
      end

      it 'should return presence policy attributes' do
        get :show, id: presence_policy.id

        expect_json(id: presence_policy.id, type: 'presence_policy', name: presence_policy.name)
      end
    end

    context 'invalid data' do
      it 'should respond with 404 when invalid id given' do
        get :show, id: '1'

        expect(response).to have_http_status(404)
      end

      it 'should respond with 404 when not account presence policy' do
        user = create(:account_user)
        Account.current = user.account

        get :show, id: presence_policy.id
        expect(response).to have_http_status(404)
      end
    end
  end

  describe 'GET #index' do
    before(:each) do
      create_list(:presence_policy, 3, account: account)
    end

    it 'should respond with success' do
      get :index

      expect(response).to have_http_status(200)
    end

    it 'should respond with account presence polciies list' do
      get :index

      expect_json_sizes(3)
    end

    it 'should return presence policy attributes' do
      get :index

      expect_json_types('*', name: :string, id: :string, type: :string)
    end

    it 'should return empty array when account does not have any presence policy' do
      Account.current.presence_policies.destroy_all

      get :index
      expect_json_sizes(0)
      expect(response.body).to eq [].to_json
    end

    it 'should not be visible in context of other account' do
      user = create(:account_user)
      Account.current = user.account

      get :index
      expect(response).to have_http_status(200)
      expect_json_sizes(0)
    end
  end

  describe 'POST #create' do
    let(:first_employee) { create(:employee, account: account) }
    let(:second_employee) { create(:employee, account: account) }
    let(:working_place) { create(:working_place, account: account) }
    let(:presence_day) { create(:presence_day) }
    let(:valid_data_json) do
      {
        name: "test",
        type: "presence_policy",
        employees: [
          {
            id: first_employee.id,
            tyoe: "employee"
          },
          {
            id: second_employee.id,
            type: "employee"
          }
        ],
        working_places: [
          {
            id: working_place.id
          }
        ],
        presence_days: [
          {
            id: presence_day.id
          }
        ]
      }
    end

    context 'valid data' do
      subject { post :create, valid_data_json }

      it { expect { subject }.to change { PresencePolicy.count }.by(1) }
      it { expect { subject }.to change { working_place.reload.presence_policy_id } }
      it { expect { subject }.to change { first_employee.reload.presence_policy_id } }
      it { expect { subject }.to change { second_employee.reload.presence_policy_id } }
      it { expect { subject }.to change { presence_day.reload.presence_policy_id } }

      context 'response' do
        before { subject }
        it { expect(response.body).to eq 'heee'}
        it { expect(response).to have_http_status(201) }
      end
    end

    context 'invalid data' do

    end
  end

  describe 'DELETE #destroy' do
    let!(:presence_policy) { create(:presence_policy, account: account) }

    context 'valid data' do
      it 'should destroy resource' do
        expect { delete :destroy, id: presence_policy.id }
          .to change { PresencePolicy.count }.by(-1)
      end

      it 'should respond with success' do
        delete :destroy, id: presence_policy.id

        expect(response).to have_http_status(204)
      end
    end

    context 'invalid data' do
      context 'presence policy has working places assigned' do
        let(:working_place) { create(:working_place, account: account) }

        it 'should not destroy presence policy' do
          presence_policy.working_places.push(working_place)

          expect { delete :destroy, id: presence_policy.id }
            .to_not change { PresencePolicy.count }
        end

        it 'should respond with status 423' do
          presence_policy.working_places.push(working_place)
          delete :destroy, id: presence_policy.id

          expect(response).to have_http_status(423)
        end
      end

      context 'presence policy has employees assigned' do
        let(:employee) { create(:employee, account: account) }

        it 'should not destroy presence policy' do
          presence_policy.employees.push(employee)

          expect { delete :destroy, id: presence_policy.id }
            .to_not change { PresencePolicy.count }
        end

        it 'should respond with status 423' do
          presence_policy.employees.push(employee)
          delete :destroy, id: presence_policy.id

          expect(response).to have_http_status(423)
        end
      end

      context 'invalid id' do
        it 'should not destroy presence policy' do
          expect { delete :destroy, id: '1' }.to_not change { PresencePolicy.count }
        end

        it 'should respond with 404' do
          delete :destroy, id: '1'

          expect(response).to have_http_status(404)
        end
      end

      context 'presence policy belongs to other account' do
        before(:each) do
          user = create(:account_user)
          Account.current = user.account
        end

        it 'should not destroy presence policy' do
          expect { delete :destroy, id: presence_policy.id }.to_not change { PresencePolicy.count }
        end

        it 'should respond with 404' do
          delete :destroy, id: presence_policy.id

          expect(response).to have_http_status(404)
        end
      end
    end
  end
end
