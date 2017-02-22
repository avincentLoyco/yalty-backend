require 'rails_helper'
require 'fakeredis/rspec'

RSpec.describe API::V1::EmployeeBalancesController, type: :controller do
  include ActiveJob::TestHelper
  include_context 'shared_context_headers'

  let(:previous_start) { related_period.first_start_date - policy.years_to_effect.years }
  let(:previous_end) { previous_start + policy.years_to_effect.years }
  let(:employee) { create(:employee, account: account) }
  let!(:etop) do
    create(:employee_time_off_policy, effective_at: employee.first_employee_event.effective_at,
      employee: employee)
  end
  let(:policy_category) do
    employee.employee_time_off_policies.first.time_off_policy.time_off_category.tap do |c|
      c.update!(account: account)
    end
  end
  let(:policy) { employee.employee_time_off_policies.first.time_off_policy }
  let(:related_period) { RelatedPolicyPeriod.new(employee.employee_time_off_policies.first) }
  let(:employee_balance) do
    create(:employee_balance,
      employee: employee,
      resource_amount: 200,
      time_off_category: policy_category,
      effective_at: previous_end + 1.week
    )
  end

  shared_examples 'Not Account Manager' do
    before { Account::User.current.update!(role: 'user') }

    it { is_expected.to have_http_status(403) }
  end

  describe 'GET #show' do
    let(:id) { employee_balance.id }
    subject { get :show, id: id }

    context 'with valid params' do
      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it { expect_json_keys(
          [
            :id, :balance, :amount, :employee, :time_off_category, :effective_at,
            :being_processed, :time_off
          ]
        )}
      end
    end

    context 'when employee is a balance owner' do
      before { Account::User.current.update!(role: 'user', employee: employee) }

      it { is_expected.to have_http_status(200) }
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
      it_behaves_like 'Not Account Manager'
    end
  end

  describe 'GET #index' do
    subject { get :index, employee_id: employee_id, time_off_category_id: category_id }
    let(:category_id) { nil }
    let(:employee_id) { employee.id }
    let!(:first_balance) { create(:employee_balance, employee: employee) }
    let!(:second_balance) { create(:employee_balance, employee: employee) }
    let!(:third_balance) do
      create(:employee_balance,
        employee: employee, time_off_category: second_balance.time_off_category
      )
    end

    it { expect(first_balance.time_off_category_id).to_not eq second_balance.time_off_category_id }

    context 'with valid data' do
      context 'when only employee_id given' do
        before { subject }

        it { expect_json_sizes(2) }
        it { is_expected.to have_http_status(200) }

        it { expect(response.body).to include(first_balance.id, third_balance.id) }
        it { expect(response.body).to_not include(second_balance.id) }
      end

      context 'when employee id and category id given' do
        let(:category_id) { second_balance.time_off_category_id }
        before { subject }

        it { expect_json_sizes(2) }
        it { is_expected.to have_http_status(200) }

        it { expect(response.body).to include(second_balance.id, third_balance.id) }
        it { expect(response.body).to_not include first_balance.id }
      end
    end

    context 'with invalid data' do
      context 'when invalid employee_id' do
        let(:employee_id) { 'abc' }

        it { is_expected.to have_http_status(404) }
      end

      context 'when invalid time_off_category_id' do
        let(:category_id) { 'abc' }

        it { is_expected.to have_http_status(404) }
      end

      it_behaves_like 'Not Account Manager'
    end
  end

  describe 'PUT #update' do
    subject { put :update, params }
    let(:amount) { '100' }
    let(:employee_id) { employee.id }
    let(:params) do
      {
        id: id,
        manual_amount: amount
      }
    end

    context 'with valid params' do
      context 'employee balance policy of type counter' do
        let(:amount) { '50' }

        include_context 'shared_context_balances',
          type: 'counter',
          years_to_effect: 0

        context 'and in current policy period' do
          let(:id) { balance.id }

          it { expect { subject }.to change { enqueued_jobs.size }.by(1) }
          it { expect { subject }.to change { balance.reload.being_processed }.to true }

          it { expect { subject }.to_not change { balance_add.reload.being_processed } }

          it { is_expected.to have_http_status(204) }
        end

        context 'and in previous policy period' do
          let(:id) { previous_balance.id }

          it { expect { subject }.to change { enqueued_jobs.size }.by(1) }
          it { expect { subject }.to change { previous_removal.reload.being_processed }.to true }
          it { expect { subject }.to change { previous_balance.reload.being_processed }.to true }
          it { expect { subject }.to change { balance_add.reload.being_processed }.to true }

          it { expect { subject }.to_not change { balance.reload.being_processed } }
        end
      end

      context 'employee balance policy of type balancer' do
        include_context 'shared_context_balances',
          type: 'balancer',
          years_to_effect: 0,
          end_day: 1,
          end_month: 4

          let(:id) { previous_balance.id }

        context 'when manual amount is negative' do
          context 'when manual amount change is greater than removal amount' do
            let(:amount) { -1100 }

            it { expect { subject }.to change { previous_balance.reload.being_processed }.to true }
            it { expect { subject }.to change { previous_removal.reload.being_processed }.to true }
            it { expect { subject }.to change { balance_add.reload.being_processed }.to true }
          end

          context 'when manual amount change is smaller than removal amount' do
            let(:amount) { -900 }

            it { expect { subject }.to change { previous_balance.reload.being_processed }.to true }
            it { expect { subject }.to change { previous_removal.reload.being_processed }.to true }
            it { expect { subject }.to_not change { balance_add.reload.being_processed } }
          end
        end

        context 'when manual amount is positive' do
          let(:amount) { 1000 }

          it { expect { subject }.to change { previous_balance.reload.being_processed }.to true }
          it { expect { subject }.to change { previous_removal.reload.being_processed }.to true }
          it { expect { subject }.to change { balance_add.reload.being_processed }.to true }
        end
      end
    end

    context 'with invalid params' do
      include_context 'shared_context_balances',
        type: 'balancer',
        years_to_effect: 0
      let(:id) { balance.id }

      context 'when param is missing' do
        before { params.delete(:manual_amount) }

        it { expect { subject }.to_not change { balance.reload.being_processed } }
        it { is_expected.to have_http_status(422) }
      end

      context 'cannot modify resource_amount' do
        before { params.merge!(validity_date: current.last - 1.month, resource_amount: 5000) }
        let(:id) { balance_add.id }

        it { expect { subject }.to change { balance_add.reload.being_processed } }
        it { expect { subject }.to_not change { balance_add.reload.resource_amount } }
        it { expect { subject }.to_not change { Employee::Balance.count } }

        it { is_expected.to have_http_status(204) }
      end

      it_behaves_like 'Not Account Manager'
    end
  end
end
