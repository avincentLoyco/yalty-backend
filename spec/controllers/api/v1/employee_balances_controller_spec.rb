require 'rails_helper'
require 'fakeredis/rspec'

RSpec.describe API::V1::EmployeeBalancesController, type: :controller do
  include ActiveJob::TestHelper
  include_context 'shared_context_headers'

  let(:previous_start) { policy.start_date - time_off_policy.years_to_effect.years }
  let(:previous_end) { policy.end_date - policy.years_to_effect.years }
  let(:employee) { create(:employee, :with_policy, account: account) }
  let(:policy_category) do
    employee.employee_time_off_policies.first.time_off_policy.time_off_category.tap do |c|
      c.update!(account: account)
    end
  end
  let(:policy) { employee.employee_time_off_policies.first.time_off_policy }
  let(:employee_balance) do
    create(:employee_balance,
      employee: employee,
      amount: 200,
      time_off_category: policy_category,
      time_off_policy: policy,
      effective_at: previous_end + 1.week
    )
  end

  describe 'GET #show' do
    subject { get :show, id: id }

    context 'with valid params' do
      let(:id) { employee_balance.id }

      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it { expect_json_keys(
          [
            :id, :balance, :amount, :employee, :time_off_category, :time_off_policy, :effective_at,
            :beeing_processed, :policy_credit_removal
          ]
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
    end
  end

  describe 'POST #create' do
    let(:amount) { '100' }
    let(:effective_at_date) { Time.now - 1.week }
    let(:employee_id) { employee.id }
    let(:params) do
      {
        amount: amount,
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

            it { expect_json(amount: 100, balance: 300) }
          end
        end

        context 'when employee balance is not last but in current policy period' do
          it { expect { subject }.to change { Employee::Balance.count }.by(1) }
          it { expect { subject }.to change { enqueued_jobs.size }.by(1) }
          it { expect { subject }.to change { employee_balance.reload.beeing_processed }.to(true) }

          it { is_expected.to have_http_status(201) }

          context 'response body' do
            before { subject }

            it { expect_json(amount: 100, balance: 100) }
          end
        end
      end

      context 'when employee balance in previous policy period' do
        let(:effective_at_date) { previous.first + 2.months }
        let(:category_id) { category.id }

        context 'and policy type is counter' do
          include_context 'shared_context_balances',
            type: 'counter',
            years_to_effect: 0

          it { expect { subject }.to change { Employee::Balance.count }.by(1) }
          it { expect { subject }.to change { previous_removal.reload.beeing_processed }.to true }
          it { expect { subject }.to change { enqueued_jobs.size }.by(1) }

          it { expect { subject }.to_not change { previous_balance.reload.beeing_processed } }
          it { expect { subject }.to_not change { balance_add.reload.beeing_processed } }
          it { expect { subject }.to_not change { balance.reload.beeing_processed } }

          it { is_expected.to have_http_status(201) }

          context 'response body' do
            before { subject }

            it { expect_json(amount: 100, balance: 1100) }
          end
        end

        context 'and policy type is balancer' do
          context 'and it does not have end date' do
            include_context 'shared_context_balances',
              type: 'balancer',
              years_to_effect: 0

            it { expect { subject }.to change { Employee::Balance.count }.by(1) }
            it { expect { subject }.to change { enqueued_jobs.size }.by(1) }

            it { expect { subject }.to change { previous_balance.reload.beeing_processed }.to true }
            it { expect { subject }.to change { balance_add.reload.beeing_processed }.to true }
            it { expect { subject }.to change { balance.reload.beeing_processed }.to true }

            it { expect { subject }.to_not change { previous_add.reload.beeing_processed } }

            it { is_expected.to have_http_status(201) }

            context 'and there is a balance with validity date' do
              let(:amount) { -500 }
              let!(:prev_mid_add) do
                create(:employee_balance, employee: employee, time_off_policy: policy,
                  time_off_category: category, amount: 1000, effective_at: previous.first + 1.week,
                  validity_date: previous.first + 3.months
                )
              end

              let!(:prev_mid_removal) do
                create(:employee_balance, employee: employee, time_off_policy: policy,
                  time_off_category: category, amount: -1000, balance_credit_addition: prev_mid_add,
                  effective_at: prev_mid_add.validity_date + 1.day, policy_credit_removal: true
                )
              end

              context 'balance smaller than removal' do
                it { expect { subject }.to change { Employee::Balance.count }.by(1) }
                it { expect { subject }.to change { enqueued_jobs.size }.by(1) }
                it { expect { subject }.to change { prev_mid_removal.reload.beeing_processed } }

                it { expect { subject }.to_not change { previous_balance.reload.beeing_processed } }
                it { expect { subject }.to_not change { balance_add.reload.beeing_processed } }
                it { expect { subject }.to_not change { balance.reload.beeing_processed } }
                it { expect { subject }.to_not change { previous_add.reload.beeing_processed } }

                it { is_expected.to have_http_status(201) }
              end

              context 'balance bigger than removal' do
                let(:amount) { -1200 }

                it { expect { subject }.to change { Employee::Balance.count }.by(1) }
                it { expect { subject }.to change { enqueued_jobs.size }.by(1) }

                it { expect { subject }.to change { prev_mid_removal.reload.beeing_processed } }
                it { expect { subject }.to change { previous_balance.reload.beeing_processed } }
                it { expect { subject }.to change { balance_add.reload.beeing_processed } }
                it { expect { subject }.to change { balance.reload.beeing_processed } }

                it { expect { subject }.to_not change { previous_add.reload.beeing_processed } }

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

              it { expect { subject }.to change { previous_balance.reload.beeing_processed } }
              it { expect { subject }.to change { previous_removal.reload.beeing_processed } }

              it { expect { subject }.to_not change { balance_add.reload.beeing_processed } }
              it { expect { subject }.to_not change { balance.reload.beeing_processed } }
              it { expect { subject }.to_not change { previous_add.reload.beeing_processed } }

              it { is_expected.to have_http_status(201) }
            end

            context 'balance removal smaller than balance' do
              let(:amount) { -1200 }

              it { expect { subject }.to change { Employee::Balance.count }.by(1) }
              it { expect { subject }.to change { enqueued_jobs.size }.by(1) }

              it { expect { subject }.to change { previous_removal.reload.beeing_processed } }
              it { expect { subject }.to change { previous_balance.reload.beeing_processed } }
              it { expect { subject }.to change { balance_add.reload.beeing_processed } }
              it { expect { subject }.to change { balance.reload.beeing_processed } }

              it { expect { subject }.to_not change { previous_add.reload.beeing_processed } }

              it { is_expected.to have_http_status(201) }
            end
          end
        end
      end
    end

    context 'with invalid data' do
      context 'params are missing' do
      end

      context 'data do not pass validation' do
      end
    end
  end

  describe 'PUT #update' do
  end

  describe 'DELETE #destroy' do
  end
end
