require 'rails_helper'

RSpec.describe API::V1::PresencePoliciesController, type: :controller do
  include_context 'shared_context_headers'

  let(:first_employee) { create(:employee, account: account) }
  let(:second_employee) { create(:employee, account: account) }
  let(:working_place) { create(:working_place, account: account) }
  let!(:second_presence_policy) { create(:presence_policy, account: account) }
  let(:presence_day) { create(:presence_day, presence_policy: second_presence_policy) }

  describe 'GET #show' do
    let(:presence_policy) { create(:presence_policy, account: account) }
    subject { get :show, id: presence_policy.id }

    context 'with valid data' do
      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it { expect_json(id: presence_policy.id, name: presence_policy.name) }
      end
    end

    context 'with invalid data' do
      context 'with invalid id' do
        subject { get :show, id: '1' }

        it { is_expected.to have_http_status(404) }
      end

      context 'with not accounts presence policy id' do
        before(:each) do
          user = create(:account_user)
          Account.current = user.account
        end

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe 'GET #index' do
    subject { get :index }
    let!(:presence_policies) { create_list(:presence_policy, 3, account: account) }

    context 'with account presence policy' do
      before { subject }

      it { expect_json_sizes(4) }
      it { is_expected.to have_http_status(200) }
      it { expect_json_types('*', name: :string, id: :string, type: :string) }
    end

    context 'with not account presence policy' do
      before(:each) do
        user = create(:account_user)
        Account.current = user.account
      end

      context 'response' do
        before { subject }

        it { expect_json_sizes(0) }
        it { expect(response.body).to eq [].to_json }
        it { expect(response).to have_http_status(200) }
      end
    end
  end

  describe 'POST #create' do
    let(:name) { 'test' }
    let(:first_employee_id) { first_employee.id }
    let(:second_employee_id) { second_employee.id }
    let(:working_place_id) { working_place.id }
    let(:valid_data_json) do
      {
        name: name,
        type: "presence_policy",
        employees: [
          {
            id: first_employee_id,
            type: "employee"
          },
          {
            id: second_employee_id,
            type: "employee"
          }
        ],
        working_places: [
          {
            id: working_place_id
          }
        ]
      }
    end

    shared_examples 'Invalid Id' do
      context 'with invalid related record id' do
        it { expect { subject }.to_not change { PresencePolicy.count } }
        it { expect { subject }.to_not change { first_employee.reload.presence_policy_id } }
        it { expect { subject }.to_not change { second_employee.reload.presence_policy_id } }
        it { expect { subject }.to_not change { working_place.reload.presence_policy_id } }

        context 'response' do
          before { subject }

          it { is_expected.to have_http_status(404) }
          it { expect_json(regex("Record Not Found")) }
        end
      end
    end

    context 'with valid data' do
      subject { post :create, valid_data_json }

      it { expect { subject }.to change { PresencePolicy.count }.by(1) }
      it { expect { subject }.to change { working_place.reload.presence_policy_id } }
      it { expect { subject }.to change { first_employee.reload.presence_policy_id } }
      it { expect { subject }.to change { second_employee.reload.presence_policy_id } }

      context 'response' do
        before { subject }

        it { is_expected.to have_http_status(201) }
        it { expect_json_types(name: :string, id: :string, type: :string) }
      end
    end

    context 'with invalid data' do
      context 'without all required attributes' do
        let(:missing_data_json) { valid_data_json.tap { |json| json.delete(:name) } }
        subject { post :create, missing_data_json }

        it { expect { subject }.to_not change { PresencePolicy.count } }
        it { expect { subject }.to_not change { working_place.reload.presence_policy_id } }

        context 'response' do
          before { subject }

          it { is_expected.to have_http_status(422) }
        end
      end

      context 'with data that do not pass validation' do
        let(:name) { '' }
        subject { post :create, valid_data_json }

        it { expect { subject }.to_not change { PresencePolicy.count } }
        it { expect { subject }.to_not change { working_place.reload.presence_policy_id } }

        context 'response' do
          before { subject }

          it { is_expected.to have_http_status(422) }
          it { expect_json(regex("can't be blank")) }
        end
      end

      context 'with wrong assosiated records ids' do
        context 'with invalid employee id' do
          let(:first_employee_id) { '1' }
          subject { post :create, valid_data_json }

          it_behaves_like 'Invalid Id'
        end

        context 'with invalid working place id' do
          let(:working_place_id) { '1' }
          subject { post :create, valid_data_json }

          it_behaves_like 'Invalid Id'
        end
      end
    end
  end

  describe 'PUT #update' do
    let(:presence_policy) { create(:presence_policy, account: account) }

    let(:id) { presence_policy.id }
    let(:name) { 'test' }
    let(:first_employee_id) { first_employee.id }
    let(:second_employee_id) { second_employee.id }
    let(:working_place_id) { working_place.id }
    let(:valid_data_json) do
      {
        id: id,
        name: name,
        type: "presence_policy",
        employees: [
          {
            id: first_employee_id,
            type: "employee"
          },
          {
            id: second_employee_id,
            type: "employee"
          }
        ],
        working_places: [
          {
            id: working_place_id
          }
        ]
      }
    end

    shared_examples 'Invalid Id' do
      context 'with invalid related record id' do
        it { expect { subject }.to_not change { presence_policy.reload.name } }
        it { expect { subject }.to_not change { presence_policy.reload.employees.count } }
        it { expect { subject }.to_not change { presence_policy.reload.working_places.count } }

        context 'response' do
          before { subject }

          it { is_expected.to have_http_status(404) }
          it { expect_json(regex("Record Not Found")) }
        end
      end
    end

    context 'with valid data' do
      subject { put :update, valid_data_json }

      it { expect { subject }.to change { presence_policy.reload.employees.count }.by(2) }
      it { expect { subject }.to change { presence_policy.reload.working_places.count }.by(1) }

      context 'response' do
        before { subject }

        it { is_expected.to have_http_status(204) }
      end

      context 'it does not overwrite records when do not send' do
        let(:policy_params) {{ name: 'test', id: presence_policy.id }}
        subject { put :update, policy_params }

        it { expect { subject }.to change { presence_policy.reload.name } }
        it { expect { subject }.to_not change { presence_policy.reload.employees.count } }
        it { expect { subject }.to_not change { presence_policy.reload.presence_days.count } }

        context 'response' do
          before { subject }

          it { is_expected.to have_http_status(204) }
        end
      end

      context 'it unassign records when empty array send' do
        let(:params) {{ name: 'test', employees: [], working_places: [], id: presence_policy.id }}
        subject { put :update, params }

        context 'with empty employee array' do
          let!(:employees) do
            create_list(:employee, 2, account: account, presence_policy: presence_policy)
          end

          it { expect { subject }.to change { presence_policy.reload.employees.count }.by(-2) }
        end

        context 'with empty working places array' do
          let!(:working_places) do
            create_list(:working_place, 2, account: account, presence_policy: presence_policy)
          end

          it { expect { subject }.to change { presence_policy.reload.working_places.count }.by(-2) }
        end
      end
    end

    context 'invalid data' do
      context 'invalid records ids' do
        context 'invalid presence policy id' do
          let(:id) { '1' }
          subject { put :update, valid_data_json }

          it_behaves_like 'Invalid Id'
        end

        context 'with invalid employee id' do
          let(:first_employee_id) { '1' }
          subject { put :update, valid_data_json }

          it_behaves_like 'Invalid Id'
        end

        context 'with invalid working place id' do
          let(:working_place_id) { '1' }
          subject { put :update, valid_data_json }

          it_behaves_like 'Invalid Id'
        end
      end

      context 'missing data' do
        let(:missing_data_json) { valid_data_json.tap { |json| json.delete(:name) } }
        subject { put :update, missing_data_json }

        it { expect { subject }.to_not change { presence_policy.reload.presence_days.count } }
        it { expect { subject }.to_not change { presence_policy.reload.employees.count } }
        it { expect { subject }.to_not change { presence_policy.reload.working_places.count } }

        context 'response' do
          before { subject }

          it { is_expected.to have_http_status(422) }
          it { expect_json(regex("missing")) }
        end
      end

      context 'data do not pass validation' do
        let(:name) { '' }
        subject { put :update, valid_data_json }

        it { expect { subject }.to_not change { presence_policy.reload.presence_days.count } }
        it { expect { subject }.to_not change { presence_policy.reload.employees.count } }
        it { expect { subject }.to_not change { presence_policy.reload.working_places.count } }

        context 'response' do
          before { subject }

          it { is_expected.to have_http_status(422) }
          it { expect_json(regex("can't be blank")) }
        end
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:presence_policy) { create(:presence_policy, account: account) }
    subject { delete :destroy, id: presence_policy.id }

    context 'valid data' do
      it { expect { subject }.to change { PresencePolicy.count }.by(-1) }
      it { is_expected.to have_http_status(204) }
    end

    context 'invalid data' do
      context 'presence policy has working places assigned' do
        let(:working_place) { create(:working_place, account: account) }
        before { presence_policy.working_places.push(working_place) }

        it { expect { subject }.to_not change { PresencePolicy.count } }
        it { is_expected.to have_http_status(423) }
      end

      context 'presence policy has employees assigned' do
        let(:employee) { create(:employee, account: account) }
        before { presence_policy.employees.push(employee) }

        it { expect { subject }.to_not change { PresencePolicy.count } }
        it { is_expected.to have_http_status(423) }
      end

      context 'invalid id' do
        subject { delete :destroy, id: '1' }

        it { expect { subject }.to_not change { PresencePolicy.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'presence policy belongs to other account' do
        before(:each) do
          user = create(:account_user)
          Account.current = user.account
        end

        it { expect { subject }.to_not change { PresencePolicy.count } }
        it { is_expected.to have_http_status(404) }
      end
    end
  end
end
