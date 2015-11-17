require 'rails_helper'

RSpec.describe API::V1::EmployeesController, type: :controller do
  include_examples 'example_authorization',
    resource_name: 'employee'
  include_context 'shared_context_headers'

  let(:attribute_definition) {
    create(
      :employee_attribute_definition,
      attribute_type: 'String',
      account: account
    )
  }

  context 'GET #show' do
    let(:employee) { create(:employee, :with_attributes, account: account) }
    subject { get :show, id: employee.id }

    context 'with valid data' do
      it { is_expected.to have_http_status(200) }

      context 'response' do
        before { subject }

        it { expect_json_keys('employee_attributes.*', [:id, :type, :value, :attribute_name]) }
        it { expect_json_types(id: :string, type: :string, employee_attributes: :array) }
      end
    end

    context 'with invalid data' do
      context 'with invalid employee id' do
        subject { get :show, id: '1' }

        it { is_expected.to have_http_status(404) }
      end

      context 'with not account employee' do
        before(:each) do
          user = create(:account_user)
          Account.current = user.account
        end

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  context 'GET #index' do
    let!(:employees) { create_list(:employee, 3, :with_attributes, account: account) }
    subject { get :index }

    it { is_expected.to have_http_status(200) }

    context 'response' do
      before { subject }

      it { expect_json_sizes(3) }
      it { expect_json_types('*', id: :string, type: :string, employee_attributes: :array) }
    end

    context 'effective at date' do
      let!(:future_employee) { create(:employee, account: account) }
      let!(:attribute) { create(:employee_attribute, event: event, employee: future_employee) }
      let!(:event) do
        create(:employee_event, employee: future_employee, effective_at: date, event_type: "hired")
      end
      let(:employee_body) do
        JSON.parse(response.body).select { |record| record['id'] == future_employee.id }.first
      end

      context 'employee with past effective_at date' do
        let(:date) { DateTime.now - 1.month }

        it { is_expected.to have_http_status(200) }

        context 'response body' do
          before { subject }

          it { expect(employee_body['employee_attributes'].first).to eql(
              'attribute_name' => attribute.attribute_definition.name,
              'value' => attribute.data.value,
              'id' => attribute.id,
              'type' => 'employee_attribute'
            )
          }
          it { expect(employee_body['id']).to eql(future_employee.id) }
          it { expect(employee_body['already_hired']).to eql true }
        end
      end

      context 'employee with future effective at date' do
        let(:date) { DateTime.now + 1.month }

        it { is_expected.to have_http_status(200) }

        context 'response body' do
          before { subject }

          it { expect(employee_body['employee_attributes'].first).to eql(
              'attribute_name' => attribute.attribute_definition.name,
              'value' => attribute.data.value,
              'id' => attribute.id,
              'type' => 'employee_attribute'
            )
          }
          it { expect(employee_body['id']).to eql(future_employee.id) }
          it { expect(employee_body['already_hired']).to eql false }
        end
      end
    end

    context 'should not be visible in context of other account' do
      before(:each) do
        user = create(:account_user)
        Account.current = user.account
      end

      it { is_expected.to have_http_status(200) }

      context 'response' do
        before { subject }

        it { expect_json_sizes(0) }
      end
    end
  end

  context 'PUT #update' do
    let(:employee) { create(:employee, account: account) }
    let(:presence_policy) { create(:presence_policy, account: account) }
    let(:holiday_policy) { create(:holiday_policy, account: account) }
    let(:id) { employee.id }
    let(:holiday_policy_id) { holiday_policy.id }
    let(:presence_policy_id) { presence_policy.id }
    let(:valid_params_json) do
      {
        id: id,
        type: 'employee',
        presence_policy: {
          id: presence_policy_id,
          type: 'presence_policy'
        },
        holiday_policy: {
          id: holiday_policy_id,
          type: 'holiday_policy'
        }
      }
    end
    subject { put :update, valid_params_json }

    context 'with valid data' do
      it { expect { subject }.to change { employee.reload.holiday_policy_id } }
      it { expect { subject }.to change { employee.reload.presence_policy_id } }

      it { is_expected.to have_http_status(204) }
    end

    context 'with invalid data' do
      context 'invalid records ids' do
        context 'invalid presence policy id' do
          let(:presence_policy_id) { '1' }

          it { expect { subject }.to_not change { employee.reload.holiday_policy_id } }
          it { expect { subject }.to_not change { employee.reload.presence_policy_id } }

          it { is_expected.to have_http_status(404) }
        end

        context 'invalid holiday policy id' do
          let(:holiday_policy_id) { '1' }

          it { expect { subject }.to_not change { employee.reload.holiday_policy_id } }
          it { expect { subject }.to_not change { employee.reload.presence_policy_id } }

          it { is_expected.to have_http_status(404) }
        end

        context 'invalid employee id' do
          let(:id) { '1' }

          it { expect { subject }.to_not change { employee.reload.holiday_policy_id } }
          it { expect { subject }.to_not change { employee.reload.presence_policy_id } }

          it { is_expected.to have_http_status(404) }
        end
      end
    end
  end
end
