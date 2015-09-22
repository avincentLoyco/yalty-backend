require 'rails_helper'

RSpec.describe API::V1::WorkingPlacesController, type: :controller do
  include_context 'shared_context_headers'

  let!(:working_place) { FactoryGirl.create(:working_place, account_id: account.id) }

  context 'GET /working_places' do
    before(:each) do
      FactoryGirl.create_list(:working_place, 3, account: account)
    end

    it 'should respond with success' do
      get :index

      expect(response).to have_http_status(:success)
    end

    it 'should not be visible in context of other account' do
      user = FactoryGirl.create(:account_user)
      Account.current = user.account

      get :index

      expect(response).to have_http_status(:success)
      expect_json_sizes(data: 0)
    end
  end

  context 'PUT /working_places/:id/assign_employee' do
    let(:first_employee) { FactoryGirl.create(:employee) }
    let(:second_employee) { FactoryGirl.create(:employee) }
    subject { put :assign_employee, params }

    context 'when valid employee ids are sended' do
      let(:params) do
        {
          id: working_place.id,
          employees: [first_employee.id, second_employee.id]
        }
      end
      it { expect { subject }.to change { working_place.reload.employees.size }.from(0).to(2) }

      context 'response' do
        before { subject }
        it { expect(response).to have_http_status(:success) }
        it { expect_json_types(name: :string,
                               account_id: :integer,
                               created_at: :date,
                               updated_at: :date,
                               id: :string,
                               employees: :array)
        }
      end
    end

    context 'when invalid employee id is sended' do
      let(:params) do
        {
          id: working_place.id,
          employees: ['1', '2']
        }
      end
      it { expect { subject }.to_not change { working_place.reload.employees.size } }

      context 'response' do
        before { subject }
        it { expect(response).to_not have_http_status(:success) }
        it { expect(response.body).to eq 'Record not found' }
      end
    end

    context 'when invalid working_place_id is sended' do
      let(:params) do
        {
          id: 'aaaaaaaa-bbbb-cccc-eeee-dddddddddddd',
          employees: [first_employee.id, second_employee.id]
        }
      end
      it { expect { subject }.to_not change { working_place.reload.employees.size } }

      context 'response' do
        before { subject }
        it { expect(response).to_not have_http_status(:success) }
        it { expect(response.body).to eq 'Record not found' }
      end
    end
  end
end
