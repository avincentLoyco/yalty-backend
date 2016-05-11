require 'rails_helper'

RSpec.describe API::V1::PresencePoliciesController, type: :controller do
  include_examples 'example_authorization',
    resource_name: 'presence_policy'
  include_context 'shared_context_headers'

  let(:first_employee) { create(:employee, account: account) }
  let(:second_employee) { create(:employee, account: account) }
  let(:working_place) { create(:working_place, account: account) }
  let!(:second_presence_policy) { create(:presence_policy, account: account) }
  let(:presence_day) { create(:presence_day, presence_policy: second_presence_policy) }

  describe 'GET #show' do
    let(:presence_policy) do
      create(:presence_policy,
        account: account,
      )
    end
    subject { get :show, id: presence_policy.id }

    context 'with valid data' do
      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before do
          create(:employee_presence_policy, presence_policy: presence_policy, employee: first_employee)
          subject
        end

        it { expect_json(id: presence_policy.id, name: presence_policy.name) }
        it { expect(response.body).to include( first_employee.id ) }
        it { expect_json_keys( [ :id, :type, :name, :presence_days, :assigned_employees ] ) }
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

    before do
      create(:employee_presence_policy, presence_policy: presence_policies.first, employee: first_employee)
      create(:employee_presence_policy, presence_policy: presence_policies.first, employee: second_employee)
    end

    context 'with account presence policy' do
      before { subject }

      it { expect_json_sizes(4) }
      it { is_expected.to have_http_status(200) }
      it { expect_json_keys( '*', [ :id, :type, :name, :presence_days, :assigned_employees ] ) }
      it { expect(response.body).to include(
        first_employee.id, second_employee.id
      )}
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
      }
    end

    shared_examples 'Invalid Id' do
      context 'with invalid related record id' do
        it { expect { subject }.to_not change { PresencePolicy.count } }

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

      context 'response' do
        before { subject }

        it { is_expected.to have_http_status(201) }
        it { expect_json_keys( [ :id, :type, :name, :presence_days, :assigned_employees ] ) }
      end

      context 'recalculating employee balances' do
        let(:employees_with_time_offs) do
          create_list(:employee, 3, :with_time_offs, account: account)
        end

        let(:first_employee_id) { employees_with_time_offs.first.id }
        let(:second_employee_id) { employees_with_time_offs.last.id }

        it { expect { subject }.to_not change {
          employees_with_time_offs.second.employee_balances.first.reload.being_processed } }
        it { expect { subject }.to change {
          employees_with_time_offs.first.employee_balances.first.reload.being_processed } }
        it { expect { subject }.to change {
          employees_with_time_offs.last.employee_balances.first.reload.being_processed } }
      end
    end

    context 'with invalid data' do
      context 'without all required attributes' do
        let(:missing_data_json) { valid_data_json.tap { |json| json.delete(:name) } }
        subject { post :create, missing_data_json }

        it { expect { subject }.to_not change { PresencePolicy.count } }

        context 'response' do
          before { subject }

          it { is_expected.to have_http_status(422) }
        end
      end

      context 'with data that do not pass validation' do
        let(:name) { '' }
        subject { post :create, valid_data_json }

        it { expect { subject }.to_not change { PresencePolicy.count } }

        context 'response' do
          before { subject }

          it { is_expected.to have_http_status(422) }
          it { expect_json(regex("can't be blank")) }
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
        type: "presence_policy"
      }
    end

    shared_examples 'Invalid Id' do
      context 'with invalid related record id' do
        it { expect { subject }.to_not change { presence_policy.reload.name } }

        context 'response' do
          before { subject }

          it { is_expected.to have_http_status(404) }
          it { expect_json(regex("Record Not Found")) }
        end
      end
    end

    context 'with valid data' do
      subject { put :update, valid_data_json }

      context 'response' do
        before { subject }

        it { is_expected.to have_http_status(204) }
      end

      context 'it does not overwrite records when do not send' do
        let(:policy_params) {{ name: 'test', id: presence_policy.id }}
        subject { put :update, policy_params }

        it { expect { subject }.to change { presence_policy.reload.name } }
        it { expect { subject }.to_not change { presence_policy.reload.presence_days.count } }

        context 'response' do
          before { subject }

          it { is_expected.to have_http_status(204) }
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
      end

      context 'missing data' do
        let(:missing_data_json) { valid_data_json.tap { |json| json.delete(:name) } }
        subject { put :update, missing_data_json }

        it { expect { subject }.to_not change { presence_policy.reload.presence_days.count } }

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
      context 'if it has an employee associated' do
        let(:employee) { create(:employee, account: account) }
        let!(:epp) do
          create(:employee_presence_policy, presence_policy: presence_policy, employee: employee)
        end
        it { is_expected.to have_http_status(423) }
        it { expect { subject }.to_not change { PresencePolicy.count } }
      end
    end

    context 'invalid data' do
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
