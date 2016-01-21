require 'rails_helper'

RSpec.describe API::V1::EmployeeBalancesController, type: :controller do
  include_examples 'example_authorization',
    resource_name: 'employee_balance'
  include_context 'shared_context_headers'

  let(:employee) { create(:employee, account: account) }
  let(:employee_balance) { create(:employee_balance, employee: employee, amount: 200) }

  describe 'GET #show' do
    subject { get :show, id: id }

    context 'with valid params' do
      let(:id) { employee_balance.id }

      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it { expect_json_keys(
          [:id, :balance, :amount, :employee, :time_off_category, :time_off_policy]
        )}
      end
    end

    context 'with invalid params' do
      context 'when invalid id' do
        let(:id) { 'abc' }

        it { is_expected.to have_http_status(404) }
      end

      context 'when balance does not belong to account user' do
        before { Account.current = create(:account) }
        let(:id) { employee_balance.id }

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe 'GET #index' do
    subject { get :index, employee_id: employee_id, time_off_category_id: category_id }
    let(:category_id) { nil }
    let(:employee_id) { employee.id }

    context 'with valid data' do
      context 'only when employee id given' do
        context 'and employee does not have balances' do
          before { subject }

          it { expect_json([]) }
          it { is_expected.to have_http_status(200) }
        end

        context 'and employee has balances' do
          let!(:employee_balance) { create(:employee_balance, employee: employee, amount: 200) }
          before { subject }

          it { is_expected.to have_http_status(200) }
          it { expect(response.body).to include(employee_balance.amount.to_s) }
        end
      end

      context 'when employee id and category id given' do
        let(:category_id) { employee_balance.time_off_category_id }

        it { is_expected.to have_http_status(200) }
      end
    end

    context 'with invalid data' do
      context 'invalid employee id' do
        let(:employee_id) { 'abc' }

        it { is_expected.to have_http_status(404) }
      end

      context 'invalid category id' do
        let(:category_id) { 'abc' }

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe 'POST #create' do
    subject { post :create, params }
    let(:params) do
      {
        amount: amount,
        type: 'employee_balance',
        time_off_category: {
          id: category_id,
          type: 'time_off_category'
        },
        employee: {
          id: employee_id,
          type: 'employee_id'
        }
      }
    end
    let(:time_off_policy) { employee_balance.time_off_policy }
    let!(:employee_time_off_policy) do
      create(:employee_time_off_policy, employee: employee, time_off_policy: time_off_policy)
    end
    let(:category) { employee_balance.time_off_category }
    let(:employee_id) { employee.id }
    let(:category_id) { category.id }
    let(:amount) { '100' }

    context 'with valid params' do
      it { expect { subject }.to change { Employee::Balance.count }.by(1) }
      it { expect { subject }.to change { category.reload.employee_balances.count }.by(1) }
      it { expect { subject }.to change { time_off_policy.reload.employee_balances.count }.by(1) }

      it { is_expected.to have_http_status(201) }

      context 'response body' do
        before { subject }

        it { expect_json_keys([:id, :amount, :balance, :time_off_category, :employee]) }
      end

      context 'balance when employee balance for employee is first' do
        before do
          allow_any_instance_of(Employee).to receive(:last_balance_in_category) { nil }
          subject
        end

        it { expect_json(balance: 100) }
      end

      context 'balance when employee balances for employee already exist' do
        before do
          allow_any_instance_of(Employee).to receive(:last_balance_in_category) { employee_balance }
          subject
        end

        it { expect_json(balance: 300) }
      end
    end

    context 'with invalid params' do
      shared_examples 'Invalid Params' do
        it { expect { subject }.to_not change { Employee::Balance.count } }
        it { expect { subject }.to_not change { category.reload.employee_balances.count } }
        it { expect { subject }.to_not change { time_off_policy.reload.employee_balances.count } }
      end

      context 'with invalid category id' do
        let(:category_id) { 'abc' }

        it_behaves_like 'Invalid Params'

        it { is_expected.to have_http_status(404) }
      end

      context 'with invalid employee id' do
        let(:employee_id) { 'abc' }

        it_behaves_like 'Invalid Params'

        it { is_expected.to have_http_status(404) }
      end

      context 'when param is missing' do
        before { params.delete(:amount) }

        it_behaves_like 'Invalid Params'

        it { is_expected.to have_http_status(422) }
      end

      context 'when amount in invalid format' do
        let(:amount) { 'abc' }

        it_behaves_like 'Invalid Params'

        it { is_expected.to have_http_status(422) }
      end

      context 'employee does not have policy in given category' do
        before do
          employee_balance.destroy!
          time_off_policy.destroy!
        end

        it { expect { subject }.to_not change { Employee::Balance.count } }
        it { expect { subject }.to_not change { category.reload.employee_balances.count } }

        it { is_expected.to have_http_status(422) }
      end
    end
  end

  describe 'PUT #update' do
    subject { put :update, params }
    let(:employee_balance) { create(:employee_balance, amount: 100, employee: employee) }
    let(:params) do
      {
        id: balance_id,
        amount: amount,
        type: 'employee_balance'
      }
    end
    let(:balance_id) { employee_balance.id }
    let(:amount) { '200' }

    context 'with valid params' do
      it { expect { subject }.to change { employee_balance.reload.amount }.from(100).to(200) }
      it { expect { subject }.to change { employee_balance.reload.balance }.by(100) }
      it { expect { subject }.to_not change { employee_balance.reload.time_off_policy } }

      it { is_expected.to have_http_status(204) }
    end

    context 'with invalid params' do
      shared_examples 'Invalid Params' do
        it { expect { subject }.to_not change { employee_balance.reload.amount } }
        it { expect { subject }.to_not change { employee_balance.reload.balance } }
        it { expect { subject }.to_not change { employee_balance.reload.time_off_policy } }
      end

      context 'invalid id' do
        let(:balance_id) { 'abc' }

        it_behaves_like 'Invalid Params'

        it { is_expected.to have_http_status(404) }
      end

      context 'param is missing' do
        before { params.delete(:amount) }

        it_behaves_like 'Invalid Params'

        it { is_expected.to have_http_status(422) }
      end

      context 'invalid amount format' do
        let(:amount) { 'abc' }

        it_behaves_like 'Invalid Params'

        it { is_expected.to have_http_status(422) }
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:employee_balance) { create(:employee_balance, employee: employee) }
    subject { delete :destroy, id: id }

    context 'with valid data' do
      let(:id) { employee_balance.id }

      it { expect { subject }.to change { Employee::Balance.count }.by(-1) }
      it { is_expected.to have_http_status(204) }
    end

    context 'with invalid data' do
      let(:id) { 'abc' }

      it { expect { subject }.to_not change { Employee::Balance.count } }
      it { is_expected.to have_http_status(404) }
    end
  end
end
