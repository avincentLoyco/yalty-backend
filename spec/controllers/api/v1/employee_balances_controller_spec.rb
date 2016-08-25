require 'rails_helper'
require 'fakeredis/rspec'

RSpec.describe API::V1::EmployeeBalancesController, type: :controller do
  include ActiveJob::TestHelper
  include_context 'shared_context_headers'

  let(:previous_start) { related_period.first_start_date - policy.years_to_effect.years }
  let(:previous_end) { previous_start + policy.years_to_effect.years }
  let(:employee) { create(:employee, :with_time_off_policy, account: account) }
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
    before { Account::User.current.update!(account_manager: false) }

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
      before { Account::User.current.update!(account_manager: false, employee: employee) }

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

  describe 'POST #create' do
    let(:amount) { '100' }
    let(:effective_at_date) { Time.now - 1.week }
    let(:employee_id) { employee.id }
    let(:params) do
      {
        manual_amount: amount,
        effective_at: effective_at_date,
        time_off_category: {
          id: category_id
        },
        employee: {
          id: employee_id
        }
      }
    end

    subject { post :create, params }

    context 'with valid data' do
      context 'for current policy period' do
        let(:category_id) { policy_category.id }
        before { employee_balance.update(effective_at: Time.now - 1.day) }

        context 'when employee_balance is last in policy' do
          before { params.delete(:effective_at) }

          it { expect { subject }.to change { Employee::Balance.count }.by(1) }
          it { expect { subject }.to_not change { enqueued_jobs.size } }

          it { is_expected.to have_http_status(201) }

          context 'response body' do
            before { subject }

            it { expect_json('0', amount: 100, balance: 300) }
          end
        end

        context 'when employee balance is not last but in current policy period' do
          it { expect { subject }.to change { Employee::Balance.count }.by(1) }
          it { expect { subject }.to change { enqueued_jobs.size }.by(1) }
          it { expect { subject }.to change { employee_balance.reload.being_processed }.to(true) }

          it { is_expected.to have_http_status(201) }

          context 'response body' do
            before { subject }

            it { expect_json('0', amount: 100, balance: 100) }
          end
        end
      end

      context 'when employee balance in previous policy period' do
        let(:effective_at_date) { previous.first + 2.months }
        let(:category_id) { category.id }
        let(:amount) { -100 }

        context 'and policy type is counter' do
          let(:effective_at_date) { previous_balance.effective_at + 2.months }
          include_context 'shared_context_balances',
            type: 'counter',
            years_to_effect: 0

          it { expect { subject }.to change { Employee::Balance.count }.by(1) }
          it { expect { subject }.to change { previous_removal.reload.being_processed }.to true }
          it { expect { subject }.to change { enqueued_jobs.size }.by(1) }
          it { expect { subject }.to change { balance_add.reload.being_processed } }

          it { expect { subject }.to_not change { previous_balance.reload.being_processed } }
          it { expect { subject }.to_not change { balance.reload.being_processed } }

          it { is_expected.to have_http_status(201) }

          context 'response body' do
            before { subject }

            it { expect_json('0', amount: -100, balance: -1100) }
          end
        end

        context 'and policy type is balancer' do
          context 'and it does not have end date' do
            include_context 'shared_context_balances',
              type: 'balancer',
              years_to_effect: 0

            it { expect { subject }.to change { Employee::Balance.count }.by(1) }
            it { expect { subject }.to change { enqueued_jobs.size }.by(1) }

            it { expect { subject }.to change { previous_balance.reload.being_processed }.to true }
            it { expect { subject }.to change { balance_add.reload.being_processed }.to true }
            it { expect { subject }.to change { balance.reload.being_processed }.to true }

            it { expect { subject }.to_not change { previous_add.reload.being_processed } }

            it { is_expected.to have_http_status(201) }

            context 'and there is a balance with validity date' do
              let(:amount) { -500 }
              let!(:prev_mid_add) do
                create(:employee_balance, employee: employee,
                  time_off_category: category, resource_amount: 1000, effective_at: previous.first + 1.week,
                  validity_date: previous.first + 3.months, policy_credit_addition: true
                )
              end

              let!(:prev_mid_removal) do
                create(:employee_balance, employee: employee,
                  time_off_category: category, resource_amount: -1000,
                  balance_credit_additions: [prev_mid_add],
                )
              end

              context 'balance smaller than removal' do
                it { expect { subject }.to change { Employee::Balance.count }.by(1) }
                it { expect { subject }.to change { enqueued_jobs.size }.by(1) }
                it { expect { subject }.to change { prev_mid_removal.reload.being_processed } }

                it { expect { subject }.to_not change { previous_balance.reload.being_processed } }
                it { expect { subject }.to_not change { balance_add.reload.being_processed } }
                it { expect { subject }.to_not change { balance.reload.being_processed } }
                it { expect { subject }.to_not change { previous_add.reload.being_processed } }

                it { is_expected.to have_http_status(201) }
              end

              context 'balance bigger than removal' do
                let(:amount) { -1200 }

                it { expect { subject }.to change { Employee::Balance.count }.by(1) }
                it { expect { subject }.to change { enqueued_jobs.size }.by(1) }

                it { expect { subject }.to change { prev_mid_removal.reload.being_processed } }
                it { expect { subject }.to change { previous_balance.reload.being_processed } }
                it { expect { subject }.to change { balance_add.reload.being_processed } }
                it { expect { subject }.to change { balance.reload.being_processed } }

                it { expect { subject }.to_not change { previous_add.reload.being_processed } }

                it { is_expected.to have_http_status(201) }
              end
            end
          end

          context 'and it does have end date' do
            include_context 'shared_context_balances',
              type: 'balancer',
              years_to_effect: 1,
              end_day: 1,
              end_month: 4

            context 'balance removal bigger or eqal balance' do
              it { expect { subject }.to change { Employee::Balance.count }.by(1) }
              it { expect { subject }.to change { enqueued_jobs.size }.by(1) }

              it { expect { subject }.to change { previous_balance.reload.being_processed } }
              it { expect { subject }.to change { previous_removal.reload.being_processed } }

              it { expect { subject }.to_not change { balance_add.reload.being_processed } }
              it { expect { subject }.to_not change { balance.reload.being_processed } }
              it { expect { subject }.to_not change { previous_add.reload.being_processed } }

              it { is_expected.to have_http_status(201) }
            end

            context 'balance removal smaller than balance' do
              let(:amount) { -1200 }

              it { expect { subject }.to change { Employee::Balance.count }.by(1) }
              it { expect { subject }.to change { enqueued_jobs.size }.by(1) }

              it { expect { subject }.to change { previous_removal.reload.being_processed } }
              it { expect { subject }.to change { previous_balance.reload.being_processed } }
              it { expect { subject }.to change { balance_add.reload.being_processed } }
              it { expect { subject }.to change { balance.reload.being_processed } }

              it { expect { subject }.to_not change { previous_add.reload.being_processed } }

              it { is_expected.to have_http_status(201) }
            end
          end
        end
      end
    end

    context 'with invalid data' do
      let(:category_id) { policy_category.id }

      context 'params are missing' do
        before { params.delete(:manual_amount) }

        it { expect { subject }.to_not change { Employee::Balance.count } }
        it { is_expected.to have_http_status(422) }
      end

      context 'data do not pass validation' do
        let(:amount) { '' }

        it { expect { subject }.to_not change { Employee::Balance.count } }
        it { is_expected.to have_http_status(422) }
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

      context 'validity date before effective at' do
        before { params.merge!({ validity_date: current.last - 1.month }) }
        let(:effective_at) { current.last - 1.week }

        it { expect { subject }.to_not change { balance.reload.being_processed } }

        it { is_expected.to have_http_status(422) }
      end

      context 'not editable balance edited' do
        before { params.merge!({ validity_date: current.last - 1.month }) }
        let(:id) { balance_add.id }

        it { expect { subject }.to_not change { balance_add.reload.being_processed } }
        it { expect { subject }.to_not change { Employee::Balance.count } }

        it { is_expected.to have_http_status(404) }
      end

      it_behaves_like 'Not Account Manager'
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, id: id }

    context 'employee balance time off policy is a counter type' do
      include_context 'shared_context_balances',
        type: 'counter',
        years_to_effect: 0

      let(:id) { balance.id }

      context 'balance is current or next policy period' do
        it { expect { subject }.to change { Employee::Balance.count }.by(-1) }

        it { expect { subject }.to_not change { previous_balance.reload.being_processed } }
        it { expect { subject }.to_not change { previous_removal.reload.being_processed } }
        it { expect { subject }.to_not change { enqueued_jobs.size } }

        it { is_expected.to have_http_status(204) }
      end

      context 'balance in previous policy period' do
        let(:id) { previous_balance.id }

        it { expect { subject }.to change { Employee::Balance.count }.by(-1) }
        it { expect { subject }.to change { previous_removal.reload.being_processed }.to true }
        it { expect { subject }.to change { enqueued_jobs.size }.by(1) }
        it { expect { subject }.to change { balance_add.reload.being_processed } }

        it { expect { subject }.to_not change { balance.reload.being_processed } }

        it { is_expected.to have_http_status(204) }
      end

      context 'not editable balance id send' do
        context 'balance is an addition' do
          let(:id) { balance_add.id }

          it { expect { subject }.to_not change { Employee::Balance.count } }
          it { expect { subject }.to_not change { enqueued_jobs.size } }

          it { is_expected.to have_http_status(404) }
        end

        context 'balance is an time off\'s balance' do
          let!(:time_off) { create(:time_off, employee: employee) }
          let(:id) { time_off.employee_balance.id }

          it { expect { subject }.to_not change { Employee::Balance.count } }
          it { expect { subject }.to_not change { enqueued_jobs.size } }

          it { is_expected.to have_http_status(404) }
        end
      end

      it_behaves_like 'Not Account Manager'
    end

    context 'employee balance time off policy is a balancer type' do
      context 'when employee balance without validity date is removed' do
        include_context 'shared_context_balances',
          type: 'balancer',
          years_to_effect: 0

        context 'in current policy period' do
          let(:id) { balance.id }

          it { expect { subject }.to change { Employee::Balance.count }.by(-1) }

          it { expect { subject }.to_not change { balance_add.reload.being_processed } }
          it { expect { subject }.to_not change { previous_balance.reload.being_processed } }
          it { expect { subject }.to_not change { enqueued_jobs.size } }

          it { is_expected.to have_http_status(204) }
        end

        context 'in previous policy period' do
          let(:id) { previous_balance.id }

          it { expect { subject }.to change { Employee::Balance.count }.by(-1) }
          it { expect { subject }.to change { enqueued_jobs.size }.by(1) }
          it { expect { subject }.to change { balance_add.reload.being_processed }.to true }
          it { expect { subject }.to change { balance.reload.being_processed }.to true }

          it { expect { subject }.to_not change { previous_add.reload.being_processed } }

          it { is_expected.to have_http_status(204) }
        end
      end

      context 'when employee with validity date is removed' do
        include_context 'shared_context_balances',
          type: 'balancer',
          years_to_effect: 1,
          end_day: 1,
          end_month: 4

        context 'and employee balance validity date in past' do
          let(:id) { previous_add.id }

          it { expect { subject }.to change { Employee::Balance.count }.by(-2) }
          it { expect { subject }.to change { enqueued_jobs.size }.by(1) }
          it { expect { subject }.to change { balance_add.reload.being_processed }.to true }
          it { expect { subject }.to change { balance.reload.being_processed }.to true }
          it { expect { subject }.to change { previous_balance.reload.being_processed }.to true }

          it { is_expected.to have_http_status(204) }
        end
      end
    end
  end
end
