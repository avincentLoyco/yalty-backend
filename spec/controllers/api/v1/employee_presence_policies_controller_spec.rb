require 'rails_helper'

RSpec.describe API::V1::EmployeePresencePoliciesController, type: :controller do
  include_context 'shared_context_headers'
  include_context 'shared_context_timecop_helper'

  let(:presence_policy) { create(:presence_policy, :with_presence_day, account: account) }
  let(:employee) { create(:employee, account: Account.current) }
  let(:presence_policy_id) { presence_policy.id }
  describe 'GET #index' do
    subject { get :index, presence_policy_id: presence_policy.id }

    let(:new_policy) { create(:presence_policy, account: account) }
    let!(:employee_presence_policy) do
      create(:employee_presence_policy, employee: employee, effective_at: Date.today)
    end
    let!(:employee_presence_policies) do
      [3.days.since, 4.days.since, 5.days.since].map do |day|
        create(:employee_presence_policy,
          presence_policy: presence_policy, employee: employee, effective_at: day
        )
      end
    end

    context 'with valid params' do
      it { is_expected.to have_http_status(200) }

      context 'response' do
        before { subject }

        it { expect_json_sizes(3) }
        it { expect(response.body).to_not include (employee_presence_policy.id) }
        it { expect_json('2', effective_till: nil, id: employee.id) }
        it { expect_json('1', effective_till: (employee_presence_policies.last.effective_at - 1.day).to_s) }
        it { expect_json('0', effective_till: (employee_presence_policies.second.effective_at - 1.day).to_s) }
        it '' do
          expect_json_keys(
            '*',
            [
              :id,
              :type,
              :assignation_type,
              :effective_at,
              :assignation_id,
              :order_of_start_day,
              :effective_till
            ]
          )
        end
      end
    end

    context 'with invalid params' do
      context 'with invalid presence_policy' do
        subject { get :index, presence_policy_id: '1' }

        it { is_expected.to have_http_status(404) }
      end

      context 'when presence policy does not belongs to current account' do
        before { Account.current = create(:account) }

        it { is_expected.to have_http_status(404) }
      end

      context 'when current account is not account manager' do
        before { Account::User.current.update!(account_manager: false) }

        it { is_expected.to have_http_status(403) }
      end
    end
  end

  describe 'POST #create' do
    subject { post :create, params }

    let(:params) do
      {
        id: employee.id,
        presence_policy_id: presence_policy_id,
        effective_at: effective_at,
        order_of_start_day: 1
      }
    end

    let(:effective_at) { Time.zone.today }
    let(:new_policy_id) { create(:presence_policy, :with_presence_day, account: account).id }

    context 'with valid params' do
      it { expect { subject }.to change { employee.employee_presence_policies.count }.by(1) }

      it { is_expected.to have_http_status(201) }

      context 'response body' do
        before { subject }

        it { expect_json(id: employee.id, effective_till: nil) }
        it '' do
          expect_json_keys([
            :id,
            :type,
            :assignation_type,
            :effective_at,
            :assignation_id,
            :order_of_start_day,
            :effective_till
          ])
        end
      end

      context 'when at least 2 EPPs exist on the past' do
        let!(:first_epp) do
          create(:employee_presence_policy, employee: employee, presence_policy: presence_policy,
            effective_at: Date.today
          )
        end
        let!(:latest_epp) do
          create(:employee_presence_policy, employee: employee, effective_at: Date.today + 1.week)
        end

        context 'and the effective at is equal to the latest EPP effective_at' do
          let(:effective_at) { latest_epp.effective_at }

          context 'and the presence policy is the same as the oldest EPP' do
            it { expect { subject }.to change { EmployeePresencePolicy.count }.by(-1) }
            it { expect { subject }.to change { EmployeePresencePolicy.exists?(latest_epp.id) } }

            it { is_expected.to have_http_status(205) }
          end

          context "and the presence policy is different than the exisitng EPP's ones" do
            let(:presence_policy_id) { new_policy_id }

            it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
            it { expect { subject }.to change { EmployeePresencePolicy.exists?(latest_epp.id) } }

            it { is_expected.to have_http_status(201) }
          end

          context 'and the presence policy is the same as latest EPP policy' do
            let(:presence_policy_id) { latest_epp.presence_policy }

            it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
            it { expect { subject }.to_not change { EmployeePresencePolicy.exists?(latest_epp.id) } }

            it { is_expected.to have_http_status(422) }
            it do
              expect(subject.body)
                .to include 'Join Table with given date and resource already exists'
            end
          end
        end

        context 'and the effective at is before the latest EPP effective_at' do
          let(:effective_at) { latest_epp.effective_at - 2.days }

          context 'and the presence policy is the same as the oldest EPP' do
            it { expect { subject }.to_not change { EmployeePresencePolicy.count } }

            it { is_expected.to have_http_status(205) }
          end

          context "and the presence policy is different than the exisitng EPP's ones" do
            let(:presence_policy_id) { new_policy_id }

            it { expect { subject }.to change { EmployeePresencePolicy.count }.by(1) }

            it { is_expected.to have_http_status(201) }
          end
        end

        context 'and the effective at is after than the latest EPP effective_at' do
          let(:effective_at) { latest_epp.effective_at + 1.week }

          context 'and the presence policy is the same as the oldest EPP' do
            it { expect { subject }.to change { EmployeePresencePolicy.count }.by(1) }

            it { is_expected.to have_http_status(201) }
          end
        end
      end
    end

    context 'with invalid params' do
      let(:new_account) { create(:account) }
      let(:category) { create(:time_off_category, account_id: employee.account_id) }
      let(:presence_policy) { create(:presence_policy, account_id: employee.account_id) }
      let(:time_off) { create(:time_off, :without_balance, employee: employee, time_off_category: category) }

      context 'when there is employee balance after effective at' do
        let!(:balance) do
          create(:employee_balance,
            employee: employee, effective_at: 1.year.ago, time_off_category: category,
            time_off: time_off
          )
        end

        it { expect { subject }.to_not change { employee.employee_presence_policies.count } }
        it { is_expected.to have_http_status(422) }
      end

      context 'when employee does not belong to current account' do
        before { employee.update!(account: new_account) }

        it { expect { subject }.to_not change { employee.employee_presence_policies.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when the presence policy does not belong to current account' do
        before { presence_policy.update!(account: new_account) }

        it { expect { subject }.to_not change { employee.employee_presence_policies.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when current user is not account manager' do
        before { Account::User.current.update!(account_manager: false) }

        it { expect { subject }.to_not change { employee.employee_presence_policies.count } }
        it { is_expected.to have_http_status(403) }
      end
    end
  end

  context 'PUT #update' do
    let(:id) { join_table_resource.id }
    let(:effective_at) { Date.new(2016, 1, 1) }
    let!(:join_table_resource) do
      create(:employee_presence_policy,
        presence_policy: new_presence_policy, employee: employee, effective_at: 10.days.ago)
    end
    let(:new_presence_policy) { presence_policy }

    subject { put :update, { id: id, effective_at: effective_at }}

    context 'with valid params' do
      it { expect { subject }.to change { join_table_resource.reload.effective_at } }

      it { is_expected.to have_http_status(200) }
      it 'should have valid data in response body' do
        subject

        expect_json(effective_at: effective_at.to_date.to_s)
        expect_json_keys([:effective_at, :effective_till, :id, :assignation_id])
      end

      context 'when at least 2 EPPs exist on the past' do
        let!(:first_epp) do
          create(:employee_presence_policy, employee: employee, presence_policy: presence_policy,
            effective_at: Date.today
          )
        end

        let!(:latest_epp) do
          create(:employee_presence_policy, employee: employee, effective_at: Date.today + 1.week)
        end

        context 'and the effective at is equal to the lastest EPP effective_at' do
          let(:effective_at) { latest_epp.effective_at }

          context 'and the presence policy is the same as the oldest EPP' do
            it { expect { subject }.to change { EmployeePresencePolicy.count }.by(-2) }
            it { expect { subject }.to change { EmployeePresencePolicy.exists?(latest_epp.id) } }
            it do
              expect { subject }
                .to change { EmployeePresencePolicy.exists?(join_table_resource.id) }
            end
          end

          context "and the presence policy is different than the exisitng EPP's ones" do
            let(:new_presence_policy) do
              create(:presence_policy, :with_presence_day, account: account)
            end

            it { expect { subject }.to change { EmployeePresencePolicy.count }.by(-1) }
            it { expect { subject }.to change { EmployeePresencePolicy.exists?(latest_epp.id) } }
          end
        end

        context 'and the effective at is before the lastest EPP effective_at' do
          let(:effective_at) { latest_epp.effective_at - 2.days }

          context 'and the presence policy is the same as the oldest EPP' do
            it { expect { subject }.to change { EmployeePresencePolicy.count }.by(-1) }
            it do
              expect { subject }
                .to change { EmployeePresencePolicy.exists?(join_table_resource.id) }
            end
          end

          context "and the presence policy is different than the exisitng EPP's ones" do
            let(:new_presence_policy) do
              create(:presence_policy, :with_presence_day, account: account)
            end

            it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
          end
        end

        context 'and the effective at is after than the lastest EPP effective_at' do
          let(:effective_at) { latest_epp.effective_at + 2.days }

          context 'and the presence policy is the same as the oldest EPP' do
            it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
          end
        end
      end
    end


    context 'with invalid params' do
      context 'when there is employee balance' do
        before do
          create(:employee_balance, :with_time_off,
            employee: employee, effective_at: balance_effective_at)
        end

        context 'after old effective_at' do
          let(:effective_at) { 5.years.ago }
          let(:balance_effective_at) { 2.days.ago }

          it { expect { subject }.to_not change { join_table_resource.reload.effective_at } }
          it { is_expected.to have_http_status(422) }

          it 'has valid error in response body' do
            subject

            expect(response.body).to include 'Employee balance after effective at already exists'
          end
        end

        context 'after new effective_at' do
          let(:effective_at) { 5.years.ago }
          let(:balance_effective_at) { 5.days.ago }

          it { expect { subject }.to_not change { join_table_resource.reload.effective_at } }
          it { is_expected.to have_http_status(422) }

          it 'has valid error in response body' do
            subject

            expect(response.body).to include 'Employee balance after effective at already exists'
          end
        end
      end

      context 'when effective at is not valid' do
        let(:effective_at) { '123' }

        it { expect { subject }.to_not change { join_table_resource.reload.effective_at } }
        it { is_expected.to have_http_status(422) }
      end

      context 'when resource is duplicated' do
        let!(:existing_resource) do
          join_table_resource.dup.tap { |resource| resource.update!(effective_at: '1/1/2016') }
        end

        it { expect { subject }.to_not change { join_table_resource.reload.effective_at } }
        it { is_expected.to have_http_status(422) }
      end

      context 'when user is not account manager' do
        before { Account::User.current.update!(account_manager: false, employee: employee) }

        it { expect { subject }.to_not change { join_table_resource.reload.effective_at } }
        it { is_expected.to have_http_status(403) }
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:id) { employee_presence_policy.id }
    let!(:employee_presence_policy) do
      create(:employee_presence_policy,
        employee: employee, presence_policy: presence_policy, effective_at: Time.now)
    end
    subject { delete :destroy, { id: id } }

    context 'with valid params' do
      context 'when they are no join tables with the same resources before and after' do
        it { expect { subject }.to change { EmployeePresencePolicy.count }.by(-1) }

        it { is_expected.to have_http_status(204) }
      end

      context 'when they are join tables with the same resources before and after' do
        let!(:same_resource_tables) do
          [Time.now - 1.week, Time.now + 1.week].map do |date|
            create(:employee_presence_policy,
              employee: employee, presence_policy: presence_policy, effective_at: date)
          end
        end

        it { expect { subject }.to change { EmployeePresencePolicy.count }.by(-2) }

        it { is_expected.to have_http_status(204) }
      end

      context 'when there is employee balance but its effective at is before resource\'s' do
        let(:employee_balance) do
          create(:employee_balance, :with_time_off, employee: employee,
            effective_at: employee_presence_policy.effective_at - 5.days)
        end

        it { expect { subject }.to change { EmployeePresencePolicy.count }.by(-1) }

        it { is_expected.to have_http_status(204) }
      end
    end

    context 'with invalid params' do
      context 'with invalid id' do
        let(:id) { '1ab' }

        it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when EmployeePresencePolicy belongs to other account' do
        before { employee_presence_policy.employee.update!(account: create(:account)) }

        it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when they are employee balances after employee_presence_policy effective at' do
        let!(:employee_balance) do
          create(:employee_balance, :with_time_off, employee: employee,
            effective_at: employee_presence_policy.effective_at + 5.days)
        end

        it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
        it { is_expected.to have_http_status(403) }
      end

      context 'when user is not an account manager' do
        before { Account::User.current.update!(account_manager: false, employee: employee) }

        it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
        it { is_expected.to have_http_status(403) }

        it 'have valid error message' do
          subject

          expect(response.body).to include 'You are not authorized to access this page.'
        end
      end
    end
  end
end
