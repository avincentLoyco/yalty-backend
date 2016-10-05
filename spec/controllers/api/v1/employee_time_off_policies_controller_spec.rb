require 'rails_helper'

RSpec.describe API::V1::EmployeeTimeOffPoliciesController, type: :controller do
  include_context 'shared_context_headers'
  include_context 'shared_context_timecop_helper'

  let(:category) { create(:time_off_category, account: Account.current) }
  let(:employee) { create(:employee, account: Account.current) }
  let(:time_off_policy) { create(:time_off_policy, :with_end_date, time_off_category: category) }
  let(:time_off_policy_id) { time_off_policy.id }

  describe 'GET #index' do
    subject { get :index, time_off_policy_id: time_off_policy_id }

    let!(:first_employee_policy) do
      create(:employee_time_off_policy,
        employee: employee, effective_at: Time.now + 1.year, time_off_policy: time_off_policy
      )
    end
    let!(:second_employee_policy) do
      create(:employee_time_off_policy,
        employee: employee, effective_at: Time.now + 5.month, time_off_policy: time_off_policy
      )
    end

    context 'with valid time_off_policy' do
      let(:time_off_policy_id) { time_off_policy.id }

      it { is_expected.to have_http_status(200) }

      context 'response' do
        before { subject }

        it { expect_json_sizes(2) }
        it { expect(response.body).to include(employee.id) }
        it { expect(response.body).to include(first_employee_policy.id, second_employee_policy.id) }
        it { expect_json('1', effective_till: nil, id: employee.id) }
        it { expect_json('0', effective_till: (first_employee_policy.effective_at - 1.day).to_s) }
        it { expect_json_keys(
          '*', [:id, :type, :assignation_id, :assignation_type, :effective_at, :effective_till])
        }
      end
    end

    context 'with invalid time_off_policy' do
      let(:time_off_policy_id) { 'a' }

      it { is_expected.to have_http_status(404) }
    end

    context 'when policy does not belong to current account' do
      before { Account.current = create(:account) }

      it { is_expected.to have_http_status(404) }
    end

    context 'when account is not account manager' do
      before { Account::User.current.update!(account_manager: false) }

      it { is_expected.to have_http_status(403) }
    end
  end

  describe 'POST #create' do
    subject { post :create, params }
    let(:effective_at) { Time.now - 1.day }
    let(:params) do
      {
        id: employee.id,
        time_off_policy_id: time_off_policy.id,
        effective_at: effective_at
      }
    end

    context 'with valid params' do
      it { expect { subject }.to change { employee.employee_time_off_policies.count }.by(1) }
      it { expect { subject }.to change { Employee::Balance.additions.count }.by(1) }
      it { expect { subject }.to change { Employee::Balance.count }.by(2) }

      it { is_expected.to have_http_status(201) }

      context 'response body' do
        before { subject }

        it do
          expect_json_keys(
            [:id, :type, :assignation_type, :effective_at, :assignation_id, :employee_balance])
        end
        it { expect_json(id: employee.id, effective_till: nil) }
      end

      context 'when policy effective at is in the past' do
        before { time_off_policy.update!(end_month: 4, end_day: 1, years_to_effect: 2) }

        let(:effective_at) { 3.years.ago - 1.day }

        it { expect { subject }.to change { employee.employee_time_off_policies.count }.by(1) }
        it { expect { subject }.to change { employee.employee_balances.additions.uniq.count }.by(4) }
        it { expect { subject }.to change { employee.employee_balances.removals.uniq.count }.by(1) }
        it { expect { subject }.to change { employee.reload.employee_balances.count }.by(6) }

        it { is_expected.to have_http_status(201) }

        context 'and assignation and date is at policy start date' do
          let(:effective_at) { 3.years.ago }

          it { expect { subject }.to change { employee.employee_time_off_policies.count }.by(1) }
          it { expect { subject }.to change { employee.employee_balances.count }.by(5) }

          it { is_expected.to have_http_status(201) }
        end
      end

      context 'with adjustment_balance_amount param given' do
        before { params.merge!(employee_balance_amount: 1000) }
        let(:effective_at) { Time.now - 1.day }

        it { expect { subject }.to change { Employee::Balance.count }.by(2) }
        it { expect { subject }.to change { employee.employee_time_off_policies.count }.by(1) }
        it { is_expected.to have_http_status(201) }

        context 'and assignation and date is at policy start date' do
          let(:effective_at) { Time.now }

          it { expect { subject }.to change { Employee::Balance.count }.by(1) }
          it { expect { subject }.to change { employee.employee_time_off_policies.count }.by(1) }
          it { is_expected.to have_http_status(201) }
        end

        context 'response body' do
          let(:new_balances) { Employee::Balance.all.order(:effective_at) }
          before { subject }

          it { expect(new_balances.first.amount).to eq 1000 }
          it { expect(new_balances.last.amount).to eq time_off_policy.amount }
          it { expect(new_balances.last.policy_credit_addition).to eq true }

          it { expect_json_keys([:id, :type, :assignation_type, :effective_at, :assignation_id]) }
          it { expect_json(id: employee.id, effective_till: nil) }
        end

        context 'when there is join table with the same resource and balance' do
          let!(:related_resource) do
            create(:employee_time_off_policy,
              time_off_policy: time_off_policy, employee: employee,
              effective_at: related_effective_at)
          end
          let!(:related_balance) do
            create(:employee_balance_manual, effective_at: related_effective_at, employee: employee,
              time_off_category: time_off_policy.time_off_category)
          end

          context 'after effective at' do
            let!(:related_effective_at) { 3.years.since }

            it { is_expected.to have_http_status(201) }
            it do
              expect { subject }.to change { EmployeeTimeOffPolicy.exists?(related_resource.id) }
            end
            it do
              expect { subject }.to change { Employee::Balance.exists?(related_balance.id) }
            end


            it 'should have proper data in response body' do
              subject

              expect_json_keys(
                :effective_at, :effective_till, :id, :assignation_id, :assignation_type,
                :employee_balance
              )
            end
          end

          context 'before effective at' do
            let(:related_effective_at) { 3.years.ago }

            it { is_expected.to have_http_status(200) }

            it { expect { subject }.to_not change { Employee::Balance.count } }
            it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }

            context 'should have proper data in response body' do
              before { subject }

              it { expect(response.body).to include (related_resource.id) }
              it do
                expect_json_keys(
                  :effective_at, :effective_till, :id, :assignation_id, :assignation_type
                )
              end
            end
          end
        end
      end
    end

    context 'with invalid params' do
      let(:new_account) { create(:account) }

      context 'when there is employee balance after effective at' do
        let!(:balance) do
          create(:employee_balance,
            employee: employee, effective_at: Time.now + 1.year, time_off_category: category
          )
        end

        it { expect { subject }.to_not change { employee.employee_time_off_policies.count } }
        it { is_expected.to have_http_status(422) }
      end

      context 'when employee does not belong to current account' do
        before { employee.update!(account: new_account) }

        it { expect { subject }.to_not change { employee.employee_time_off_policies.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when time off policy does not belong to current account' do
        before { category.update!(account: new_account) }

        it { expect { subject }.to_not change { employee.employee_time_off_policies.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when user is not account manager' do
        before { Account::User.current.update!(account_manager: false) }

        it { is_expected.to have_http_status(403) }
      end
    end

    context 'when effective at is before employee start date' do
      before { subject }
      let(:effective_at) { Time.now - 20.years }

      it { is_expected.to have_http_status(422) }
      it { expect(response.body).to include 'can\'t be set before employee hired date' }
    end
  end
end
