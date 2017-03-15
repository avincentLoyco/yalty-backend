require 'rails_helper'

RSpec.describe API::V1::PresencePoliciesController, type: :controller do
  include_context 'shared_context_active_and_inactive_resources',
    resource_class: PresencePolicy.model_name,
    join_table_class: EmployeePresencePolicy.model_name
  include_examples 'example_authorization',
    resource_name: 'presence_policy'
  include_context 'shared_context_headers'

  let(:first_employee) { create(:employee, account: account) }
  let(:second_employee) { create(:employee, account: account) }
  let(:working_place) { create(:working_place, account: account) }

  describe 'GET #show' do
    let(:presence_policy) do
      create(:presence_policy, :with_presence_day,
        account: account,
      )
    end
    subject { get :show, id: presence_policy.id }

    context 'with valid data' do
      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before do
          create(:employee_presence_policy,
            presence_policy: presence_policy,
            employee: first_employee)
          subject
        end

        it { expect_json(id: presence_policy.id, name: presence_policy.name) }
        it { expect(response.body).to include(first_employee.id) }
        it { expect_json_keys([:id, :type, :name, :deletable, :presence_days, :assigned_employees]) }
        it { expect_json('deletable', false) }
      end

      context 'without employees' do
        before { subject }

        it { expect_json('deletable', true) }
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
    let!(:presence_policies) do
      create_list(:presence_policy, 3, :with_presence_day, account: account)
    end

    before do
      create(:employee_presence_policy, presence_policy: presence_policies.first, employee: first_employee)
      create(:employee_presence_policy, presence_policy: presence_policies.first, employee: second_employee)
    end

    context 'with account presence policy' do
      before { subject }
      let(:presence_policy_with_employees) do
        JSON.parse(response.body).select { |p| p['assigned_employees'].present? }.first
      end
      let(:presence_policy_without_employees) do
        JSON.parse(response.body).select { |p| p['assigned_employees'].empty? }.first
      end

      it { expect_json_sizes(3) }
      it { is_expected.to have_http_status(200) }
      it do
        expect_json_keys('*', [:id, :type, :name, :deletable, :presence_days, :assigned_employees])
      end
      it { expect(response.body).to include(first_employee.id, second_employee.id) }

      it { expect(presence_policy_with_employees['deletable']).to be false }
      it { expect(presence_policy_without_employees['deletable']).to be true }
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

      context 'when days params are present' do
        subject { post :create, valid_data_json.merge(presence_days: days_params) }
        let(:days_params) do
          [
            {
              time_entries: [{ start_time: '12:00:00', end_time: '16:00:00' }],
              minutes: 40,
              order: 1
            },
            {
              time_entries: [{ start_time: '12:00:00', end_time: '16:00:00' }],
              minutes: 40,
              order: 7
            }
          ]
        end

        context 'and there is day with order 7' do
          it { expect { subject }.to change { PresencePolicy.count }.by(1) }
          it { expect { subject }.to change { PresenceDay.count }.by(2) }
          it { expect { subject }.to change { TimeEntry.count }.by(2) }

          it { is_expected.to have_http_status(201) }
        end

        context 'and there is no day with order 7' do
          before { days_params.pop }

          it { expect { subject }.to change { PresencePolicy.count }.by(1) }
          it { expect { subject }.to change { PresenceDay.count }.by(1) }
          it { expect { subject }.to change { TimeEntry.count }.by(1) }

          it { is_expected.to have_http_status(201) }
        end
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
          it { expect_json(regex("must be filled")) }
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

      context 'and the policy is already assigned to an employee' do
        before do
          presence_policy.update!(presence_days: [create(:presence_day)])
          create(:employee_presence_policy,
            employee: first_employee,
            presence_policy: presence_policy
          )
        end

        it { is_expected.to have_http_status(423) }
        it { expect { subject }.to_not change { presence_policy.reload.name } }
        it { expect { subject }.to_not change { presence_policy.reload.presence_days.count } }
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
          it { expect_json(regex("must be filled")) }
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

      context 'and the policy is already assigned to an employee' do
        before { presence_policy.update!(presence_days: [create(:presence_day)]) }
        let(:employee) { create(:employee, account: account) }
        let!(:epp) do
          create(:employee_presence_policy, presence_policy: presence_policy, employee: employee)
        end
        it { is_expected.to have_http_status(423) }
        it { expect { subject }.to_not change { PresencePolicy.count } }
      end

      context 'if it has an presence_day associated' do
        let(:employee) { create(:employee, account: account) }
        let!(:presence_day) do
          create(:presence_day, presence_policy: presence_policy)
        end
        it { is_expected.to have_http_status(204) }
        it { expect { subject }.to change {PresencePolicy.count}.by(-1) }
        it { expect { subject }.to change {PresenceDay.count}.by(-1) }
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
