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

    let!(:etop) do
      create(:employee_time_off_policy, employee: employee, effective_at: 7.days.since)
    end
    let!(:etops) do
      [3.days.ago, 1.day.ago, 5.days.since].map do |day|
        create(:employee_time_off_policy,
          time_off_policy: time_off_policy, employee: employee, effective_at: day
        )
      end
    end

    context 'with valid params' do
      it 'has valid keys in json' do
        subject

        expect_json_keys(
          '*',
          [
            :id,
            :type,
            :assignation_type,
            :effective_at,
            :assignation_id,
            :effective_till,
            :employee_balance
          ]
        )
      end

      context 'when no filter param given' do
        it { is_expected.to have_http_status(200) }

        it 'has valid employee presence policies in response' do
          subject

          expect(response.body).to include(etops.second.id, etops.last.id)
          expect(response.body).to_not include(etops.first.id, etop.id)
        end
      end

      context 'when filter active param given' do
        subject { get :index, time_off_policy_id: time_off_policy.id, filter: 'active' }

        it { is_expected.to have_http_status(200) }

        it 'has valid employee presence policies in response' do
          subject

          expect(response.body).to include(etops.second.id, etops.last.id)
          expect(response.body).to_not include(etops.first.id, etop.id)
        end
      end

      context 'when filter inactive param given' do
        subject { get :index, time_off_policy_id: time_off_policy.id, filter: 'inactive' }

        it { is_expected.to have_http_status(200) }

        it 'has valid employee presence policies in response' do
          subject

          expect(response.body).to include(etops.first.id)
          expect(response.body).to_not include(etops.second.id, etops.last.id, etop.id)
        end
      end

      context 'when filter all param given' do
        subject { get :index, time_off_policy_id: time_off_policy.id, filter: 'all' }

        it { is_expected.to have_http_status(200) }

        it 'has valid employee presence policies in response' do
          subject

          expect(response.body).to include(etops.first.id, etops.second.id, etops.last.id)
          expect(response.body).to_not include(etop.id)
        end
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
        time_off_policy_id: time_off_policy_id,
        effective_at: effective_at
      }
    end

    context 'with valid params' do
      it { expect { subject }.to change { employee.employee_time_off_policies.count }.by(1) }
      it { expect { subject }.to change { Employee::Balance.additions.count }.by(3) }
      it { expect { subject }.to change { Employee::Balance.count }.by(10) }

      it { is_expected.to have_http_status(201) }

      context 'response body' do
        before { subject }

        it do
          expect_json_keys(
            [:id, :type, :assignation_type, :effective_at, :assignation_id, :employee_balance])
        end
        it { expect_json(id: employee.id, effective_till: nil) }
      end

      context 'when creating etop in place of another' do
        let(:effective_at) { Date.new(2014, 1, 1) }
        let(:top_a) { time_off_policy }
        let(:top_b) do
          create(:time_off_policy, time_off_category: category, end_day: 1, end_month: 5,
            years_to_effect: 1, start_month: 2)
        end
        let!(:etop_1) do
          create(:employee_time_off_policy, time_off_policy: top_a, employee: employee,
            effective_at: Time.zone.parse('2013-01-01'))
        end
        let!(:etop_2) do
          create(:employee_time_off_policy, time_off_policy: top_b, employee: employee,
            effective_at: Time.zone.parse('2014-01-01'))
        end
        let(:balance_effective_ats) { Employee::Balance.pluck(:effective_at).map(&:to_date) }
        let(:expected_balances_dates) do
          ['2013-01-01', '2013-12-31', '2014-01-01', '2014-04-01', '2014-12-31', '2015-01-01',
           '2015-04-01', '2015-12-31', '2016-01-01', '2016-04-01', '2016-12-31', '2017-01-01',
           '2017-04-01', '2017-12-31', '2018-01-01', '2018-04-01', '2019-04-01'].map(&:to_date)
        end

        before do
          EmployeeTimeOffPolicy.order(:effective_at).each do |etop|
            RecreateBalances::AfterEmployeeTimeOffPolicyCreate.new(
              time_off_category_id: etop.time_off_category_id,
              employee_id: etop.employee_id,
              new_effective_at: etop.effective_at
            ).call
          end
          subject
        end

        it { expect(balance_effective_ats).to match_array(expected_balances_dates) }
        it { expect(EmployeeTimeOffPolicy.count).to eq(1) }
      end

      context 'when policy effective at is in the past' do
        before { time_off_policy.update!(end_month: 4, end_day: 1, years_to_effect: 2) }

        let(:effective_at) { 3.years.ago - 1.day }

        it { expect { subject }.to change { employee.employee_time_off_policies.count }.by(1) }
        it { expect { subject }.to change { employee.employee_balances.additions.uniq.count }.by(7) }
        it { expect { subject }.to change { employee.employee_balances.removals.uniq.count }.by(7) }
        it { expect { subject }.to change { employee.reload.employee_balances.count }.by(22) }

        it { is_expected.to have_http_status(201) }

        context 'and assignation and date is at policy start date' do
          let(:effective_at) { 3.years.ago }

          it { expect { subject }.to change { employee.employee_time_off_policies.count }.by(1) }
          it { expect { subject }.to change { employee.employee_balances.count }.by(20) }

          it { is_expected.to have_http_status(201) }
        end
      end

      context 'with adjustment_balance_amount param given' do
        before { params.merge!(employee_balance_amount: 1000) }
        let(:effective_at) { Time.now - 1.day }

        it { expect { subject }.to change { Employee::Balance.count }.by(10) }
        it { expect { subject }.to change { employee.employee_time_off_policies.count }.by(1) }
        it { is_expected.to have_http_status(201) }

        context 'and assignation and date is at policy start date' do
          let(:effective_at) { Time.now }

          it { expect { subject }.to change { Employee::Balance.count }.by(8) }
          it { expect { subject }.to change { employee.employee_time_off_policies.count }.by(1) }
          it { is_expected.to have_http_status(201) }
        end

        context 'response body' do
          let(:new_balances) { Employee::Balance.order(:effective_at) }
          before { subject }

          it { expect(new_balances.second.amount).to eq 1000 }
          it { expect(new_balances.additions.last.amount).to eq time_off_policy.amount }
          it { expect(new_balances.additions.last.policy_credit_addition).to eq true }

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

            before do
              EmployeeTimeOffPolicy.order(:effective_at).each do |etop|
                RecreateBalances::AfterEmployeeTimeOffPolicyCreate.new(
                  time_off_category_id: etop.time_off_category_id,
                  employee_id: etop.employee_id,
                  new_effective_at: etop.effective_at
                ).call
              end
            end

            it { is_expected.to have_http_status(205) }

            it { expect { subject }.to_not change { Employee::Balance.count } }
            it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
          end
        end
      end

      context 'when one ETOP of a different category exsists with assignation on the same day' do
        let!(:past_etop) do
          top = create(:time_off_policy, time_off_category: category)
          create(:employee_time_off_policy, employee: employee, time_off_policy: top,
            effective_at: effective_at)
        end

        context 'and the effective at is equal to this already existing ETOP effective_at' do
          it { expect { subject }.to change { EmployeeTimeOffPolicy.exists?(past_etop.id) } }
          it { expect { subject }.to change { Employee::Balance.additions.count }.by(3) }
          it { expect { subject }.to change { Employee::Balance.count }.by(10) }
        end
      end

      context 'when one ETOP of the same category already exists with assignation on the same day' do
        let!(:past_etop) do
          create(:employee_time_off_policy, employee: employee, time_off_policy: time_off_policy,
            effective_at: effective_at)
        end

        context "and it's policy is the same as the policy as the ETOP being created" do
          it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
          it { expect { subject }.to_not change { Employee::Balance.count } }

          it { is_expected.to have_http_status(422) }
        end

        context "and it's policy is a different one than the policy as the ETOP being created " do
          let(:time_off_policy_id) { create(:time_off_policy, time_off_category: category).id }

          it { expect { subject }.to change { EmployeeTimeOffPolicy.exists?(past_etop.id) } }

          it { is_expected.to have_http_status(201) }
        end
      end

      context 'when at least 2 ETOPs of the same category exist on the past' do
        let!(:first_etop) do
          create(:employee_time_off_policy, employee: employee, time_off_policy: time_off_policy,
            effective_at: Date.today
          )
        end

        let!(:latest_etop) do
          top = create(:time_off_policy, time_off_category: category)
          create(:employee_time_off_policy, :with_employee_balance,
            employee: employee, time_off_policy: top, effective_at: Date.today + 1.week
          )
        end

        let(:create_balances_for_existing_etops) do
          EmployeeTimeOffPolicy.order(:effective_at).each do |etop|
            RecreateBalances::AfterEmployeeTimeOffPolicyCreate.new(
              new_effective_at: etop.effective_at,
              time_off_category_id: category.id,
              employee_id: employee.id
            ).call
          end
        end

        context 'and the effective at is equal to the latest ETOP effective_at' do
          let(:effective_at) { latest_etop.effective_at }

          context 'and the time off policy is the same as the oldest ETOP' do
            before { create_balances_for_existing_etops }

            it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-1) }
            it { expect { subject }.to change { Employee::Balance.count }.by(1) }

            it { is_expected.to have_http_status(205) }
          end

          context "and the time off policy is different than the exisitng ETOP's ones" do
            let(:time_off_policy_id) { create(:time_off_policy, time_off_category: category).id }

            it { expect { subject }.to change { EmployeeTimeOffPolicy.exists?(latest_etop.id) } }
            it { is_expected.to have_http_status(201) }
          end
        end

        context 'and the effective at is before the latest ETOP effective_at' do
          let(:effective_at) { latest_etop.effective_at - 2.days }
          let(:time_off_policy_id) { latest_etop.time_off_policy_id }

          before { create_balances_for_existing_etops }

          context 'and the time off policy is the same as the oldest ETOP' do
            it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
            it { expect { subject }.to change { EmployeeTimeOffPolicy.exists?(latest_etop.id) } }
            it { expect { subject }.to_not change { Employee::Balance.count } }
          end
        end

        context 'and the effective at is after than the latest ETOP effective_at' do
          let(:effective_at) { latest_etop.effective_at + 2.days }

          context 'and the time off policy is the same as the oldest ETOP' do
            it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(1) }
            it { expect { subject }.to change { Employee::Balance.count }.by(8) }

            it { is_expected.to have_http_status(201) }
          end

          context "and the time off policy is different than the exisitng ETOP's ones" do
            let(:time_off_policy_id) { create(:time_off_policy, time_off_category: category).id }

            it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(1) }
            it { expect { subject }.to change { Employee::Balance.count }.by(5) }

            it { is_expected.to have_http_status(201) }
          end
        end
      end
    end

    context 'with invalid params' do
      let(:new_account) { create(:account) }

      context 'when there is employee balance after effective at' do
        let!(:balance) do
          create(:employee_balance,
            employee: employee, effective_at: 1.year.since, time_off_category: category
          )
        end

        it { expect { subject }.to change { employee.employee_time_off_policies.count } }
        it { is_expected.to have_http_status(201) }
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

      context 'when effective at is invalid format' do
        let(:effective_at) { '**' }

        it { expect { subject }.to_not change { employee.employee_presence_policies.count } }
        it { is_expected.to have_http_status(422) }
      end
    end

    context 'when effective at is before employee start date' do
      before { subject }
      let(:effective_at) { 20.years.ago }

      it { is_expected.to have_http_status(422) }
      it { expect(response.body).to include 'can\'t be set before employee hired date' }
    end
  end

  context 'PUT #update' do
    let(:id) { join_table_resource.id }
    let(:effective_at) { Date.new(2016, 1, 1) }
    let!(:join_table_resource) do
      create(:employee_time_off_policy, time_off_policy: time_off_policy, employee: employee)
    end

    subject { put :update, { id: id, effective_at: effective_at }}

    context 'with valid params' do
      it { expect { subject }.to change { join_table_resource.reload.effective_at } }
      it { is_expected.to have_http_status(200) }

      context 'when moving one etop in place of another' do
        let(:top_a) { time_off_policy }
        let(:top_b) do
          create(:time_off_policy, time_off_category: category, end_day: 1, end_month: 5,
            years_to_effect: 1, start_month: 2)
        end
        let(:balance_effective_ats) { Employee::Balance.pluck(:effective_at).map(&:to_date) }

        context 'to past' do
          let(:effective_at) { Date.new(2014, 1, 1) }
          let!(:etop_1) do
            create(:employee_time_off_policy, time_off_policy: top_a, employee: employee,
              effective_at: Time.zone.parse('2013-01-01'))
          end
          let!(:etop_2) do
            create(:employee_time_off_policy, time_off_policy: top_b, employee: employee,
              effective_at: Time.zone.parse('2014-01-01'))
          end
          let(:expected_balances_dates) do
            ['2013-01-01', '2013-12-31', '2014-01-01', '2014-04-01', '2014-12-31', '2015-01-01',
             '2015-04-01', '2015-12-31', '2016-01-01', '2016-04-01', '2016-12-31', '2017-01-01',
             '2017-04-01', '2017-12-31', '2018-01-01', '2018-04-01', '2019-04-01'].map(&:to_date)
          end

          before do
            EmployeeTimeOffPolicy.order(:effective_at).each do |etop|
              RecreateBalances::AfterEmployeeTimeOffPolicyCreate.new(
                time_off_category_id: etop.time_off_category_id,
                employee_id: etop.employee_id,
                new_effective_at: etop.effective_at
              ).call
            end
            subject
          end

          it { expect(balance_effective_ats).to match_array(expected_balances_dates) }
          it { expect(EmployeeTimeOffPolicy.count).to eq(1) }
        end

        context 'to future' do
          let(:effective_at) { Date.new(2017, 1, 1) }
          let!(:etops) do
            [
              Time.zone.parse('2014-01-01'),
              Time.zone.parse('2016-01-01'),
              Time.zone.parse('2018-01-01')
            ].each do |date|
              create(:employee_time_off_policy, time_off_policy: top_b, employee: employee,
                effective_at: date)
            end
          end
          let!(:etop_at_2017) do
            create(:employee_time_off_policy, time_off_policy: top_a, employee: employee,
              effective_at: Time.zone.parse('2017-01-01'))
          end
          let(:expected_balances_dates) do
            ['2015-01-01', '2016-01-01', '2016-01-31', '2016-02-01', '2016-04-01', '2017-01-31',
             '2017-02-01', '2017-05-01', '2018-05-01'].map(&:to_date)
          end
          let(:id) { EmployeeTimeOffPolicy.order(:effective_at).first.id }

          before do
            EmployeeTimeOffPolicy.order(:effective_at).each do |etop|
              RecreateBalances::AfterEmployeeTimeOffPolicyCreate.new(
                time_off_category_id: etop.time_off_category_id,
                employee_id: etop.employee_id,
                new_effective_at: etop.effective_at
              ).call
            end
            subject
          end

          it { expect(balance_effective_ats).to match_array(expected_balances_dates) }
          it { expect(EmployeeTimeOffPolicy.count).to eq(2) }
        end
      end

      context 'when join table has assignation balance' do
        let(:effective_at) { Date.new(2014, 1, 1) }
        let(:assignation_balance) { join_table_resource.reload.policy_assignation_balance }

        before do
          create(
            :employee_balance_manual,
            time_off_category: category,
            employee: employee,
            effective_at: join_table_resource.effective_at +
                          Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
            manual_amount: 2000
          )
        end

        it { expect { subject }.to change { join_table_resource.reload.effective_at } }
        it { expect { subject }.to change { Employee::Balance.count }.by(13) }
        it { is_expected.to have_http_status(200) }

        it 'affects assignation balance' do
          subject
          expect(assignation_balance.effective_at.to_date).to eq(effective_at)
          expect(assignation_balance.resource_amount).to eq(time_off_policy.amount)
          expect(assignation_balance.manual_amount).to eq(2000)
        end
      end

      context 'when there is resource in the same date but in different time off category' do
        let(:second_category) { create(:time_off_category, account: Account.current) }
        let(:second_time_off_policy) { create(:time_off_policy, time_off_category: second_category) }
        let!(:existing_table) do
          create(:employee_time_off_policy, :with_employee_balance,
            time_off_policy: second_time_off_policy, employee: employee, effective_at: '1/1/2016')
        end

        it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
        it { expect { subject }.to change { Employee::Balance.count }.by(8) }

        it { expect { subject }.to change { join_table_resource.reload.effective_at } }

        it 'should have valid data in response body' do
          subject

          expect_json(effective_at: effective_at.to_date.to_s)
          expect_json_keys([:effective_at, :effective_till, :id, :assignation_id])
        end
      end

      context 'when employee_time_off_policy start date passed' do
        let(:effective_at) { 2.years.ago }

        it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
        it { expect { subject }.to change { Employee::Balance.count }.by(14) }
        it { expect { subject }.to change { Employee::Balance.additions.count }.by(5) }

        it { expect { subject }.to change { join_table_resource.reload.effective_at } }

        it 'should create employee balances with proper effective at' do
          subject

          expect(Employee::Balance.all.order(:effective_at).pluck(:effective_at).map(&:to_date))
            .to eq(
              [
                Date.new(2014, 1, 1),
                Date.new(2014, 12,31),
                Date.new(2015, 1, 1),
                Date.new(2015, 4, 1),
                Date.new(2015, 12, 31),
                Date.new(2016, 1, 1),
                Date.new(2016, 4, 1),
                Date.new(2016, 12, 31),
                Date.new(2017, 1, 1),
                Date.new(2017, 4, 1),
                Date.new(2017, 12, 31),
                Date.new(2018, 1, 1),
                Date.new(2018, 4, 1),
                Date.new(2019, 4, 1)
              ]
            )
        end

        it 'should have valid data in response body' do
          subject

          expect_json(effective_at: effective_at.to_date.to_s)
          expect_json_keys([:effective_at, :effective_till, :id, :assignation_id])
        end
      end

      context 'when one ETOP of a different category exsists on the past' do
        let!(:past_etop) do
          top = create(:time_off_policy, time_off_category: category)
          create(:employee_time_off_policy, :with_employee_balance,
            employee: employee, time_off_policy: top, effective_at: effective_at)
        end

        context 'and the effective at is equal to this already existing ETOP effective_at' do
          it { expect { subject }.to change { EmployeeTimeOffPolicy.exists?(past_etop.id) } }
          it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-1) }

          it { is_expected.to have_http_status(200) }
        end
      end

      context 'when one ETOP of the same category already exists on the past' do
        let!(:past_etop) do
          top = create(:time_off_policy, time_off_category: category)
          create(:employee_time_off_policy, employee: employee, time_off_policy: top,
            effective_at: effective_at)
        end

        context "and it's policy is the same as the policy as the ETOP being created" do
          let(:time_off_policy) { past_etop.time_off_policy }

          it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }

          it { is_expected.to have_http_status(422) }
        end

        context "and it's policy is a different one than the policy as the ETOP being created " do
          it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-1) }

          it { is_expected.to have_http_status(200) }
        end
      end

      context 'when at least 2 ETOPs of the same category exist on the past' do
        let!(:first_etop) do
          create(:employee_time_off_policy, employee: employee, time_off_policy: time_off_policy,
            effective_at: Date.today
          )
        end
        let!(:latest_etop) do
          top = create(:time_off_policy, time_off_category: category)
          create(:employee_time_off_policy, employee: employee, time_off_policy: top,
            effective_at: Date.today + 1.week
          )
        end

        context 'and the effective at is equal to the latest ETOP effective_at' do
          let(:effective_at) { latest_etop.effective_at }

          context 'and the time off policy is the same as the oldest ETOP' do
            it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-2) }
            it { expect { subject }.to change { EmployeeTimeOffPolicy.exists?(latest_etop.id) } }
            it { expect { subject }.to change { EmployeeTimeOffPolicy.exists?(id) } }
          end

          context "and the time off policy is different than the exisitng ETOP's ones" do
            before do
              join_table_resource.update!(
                time_off_policy: create(:time_off_policy, time_off_category: category)
              )
            end

            it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-1) }
            it { expect { subject }.to change { EmployeeTimeOffPolicy.exists?(latest_etop.id) } }
            it { expect { subject }.to_not change { EmployeeTimeOffPolicy.exists?(id) } }
          end
        end

        context 'and the effective at is before the latest ETOP effective_at' do
          let(:effective_at) { latest_etop.effective_at - 2.days }

          context 'and the time off policy is the same as the oldest ETOP' do
            it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-1) }
            it { expect { subject }.to change { EmployeeTimeOffPolicy.exists?(id) } }

            it { is_expected.to have_http_status(205) }

            context 'and employee time off policy has assignation balance' do
              let!(:employee_balance) do
                create(
                  :employee_balance_manual,
                  time_off_category: category,
                  employee: employee,
                  effective_at: join_table_resource.effective_at +
                                Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
                  manual_amount: 2000)
              end

              it { is_expected.to have_http_status(205) }

              it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-1) }
              it { expect { subject }.to change { EmployeeTimeOffPolicy.exists?(id) } }
              it { expect { subject }.to change { Employee::Balance.exists?(employee_balance.id) } }
            end
          end

          context "and the time off policy is different than the exisitng ETOP's ones" do
            before do
              join_table_resource.update!(
                time_off_policy: create(:time_off_policy, time_off_category: category)
              )
            end

            it { expect { subject }.to_not change { EmployeeTimeOffPolicy.exists?(id) } }
            it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }

            it { is_expected.to have_http_status(200) }
          end
        end

        context 'and the effective at is after than the latest ETOP effective_at' do
          let(:effective_at) { latest_etop.effective_at + 2.days }

          before do
            EmployeeTimeOffPolicy.order(:effective_at).each do |etop|
              RecreateBalances::AfterEmployeeTimeOffPolicyCreate.new(
                time_off_category_id: etop.time_off_category_id,
                employee_id: etop.employee_id,
                new_effective_at: etop.effective_at
              ).call
            end
          end

          context 'and the time off policy is the same as the latest ETOP' do
            before do
              join_table_resource.update!(time_off_policy: latest_etop.time_off_policy)
            end

            it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-1) }
            it { expect { subject }.to change { EmployeeTimeOffPolicy.exists?(id) } }

            it { is_expected.to have_http_status(205) }
          end

          context "and the time off policy is different than the exisitng ETOP's ones" do
            it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
            it { expect { subject }.to change { join_table_resource.reload.effective_at } }

            it { is_expected.to have_http_status(200) }
          end
        end
      end
    end

    context 'with invalid params' do
      context 'when there is employee balance' do
        before do
          create(:time_off,
            time_off_category: category, employee: employee, end_time: time_off_effective_at,
            start_time: time_off_effective_at - 2.days)
        end

        context 'after old effective_at' do
          let(:effective_at) { 5.years.since }
          let(:time_off_effective_at) { 2.days.since }

          it { expect { subject }.to change { join_table_resource.reload.effective_at } }
          it { is_expected.to have_http_status(200) }

          it 'returns valid response' do
            subject

            expect(response.body).to include join_table_resource.id
          end
        end

        context 'after new effective_at' do
          let(:effective_at) { 5.years.ago }
          let(:time_off_effective_at) { 5.days.ago }

          it { expect { subject }.to change { join_table_resource.reload.effective_at } }
          it { is_expected.to have_http_status(200) }

          it 'returns valid response' do
            subject

            expect(response.body).to include join_table_resource.id
          end
        end
      end

      context 'when effective at is not valid' do
        let(:effective_at) { '1-a-b' }

        it { expect { subject }.to_not change { join_table_resource.reload.effective_at } }
        it { is_expected.to have_http_status(422) }
      end

      context 'when resource is duplicated' do
        let!(:existing_resource) do
          join_table_resource.dup.tap { |resource| resource.update!(effective_at: effective_at) }
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
    let(:employee_time_off_policy) do
      create(:employee_time_off_policy, :with_employee_balance,
        employee: employee, time_off_policy: time_off_policy, effective_at: Time.now)
    end
    let(:id) { employee_time_off_policy.id }

    subject { delete :destroy, id: id }

    context 'with valid params' do
      context 'when removing etop between the same etops' do
        let(:id) { etop_b.id }
        let(:top_a) { time_off_policy }
        let(:top_b) do
          create(:time_off_policy, time_off_category: category, end_day: 1, end_month: 5,
            years_to_effect: 1, start_month: 2)
        end
        let!(:etops_a) do
          [Time.zone.parse('2013-01-01'), Time.zone.parse('2015-01-01')].each do |date|
            create(:employee_time_off_policy, time_off_policy: top_a, employee: employee,
              effective_at: date)
          end
        end
        let!(:etop_b) do
          create(:employee_time_off_policy, time_off_policy: top_b, employee: employee,
            effective_at: Time.zone.parse('2014-01-01'))
        end
        let(:balance_effective_ats) { Employee::Balance.pluck(:effective_at).map(&:to_date) }
        let(:expected_balances_dates) do
          ['2013-01-01', '2013-12-31', '2014-01-01', '2014-04-01', '2014-12-31', '2015-01-01',
           '2015-04-01', '2015-12-31', '2016-01-01', '2016-04-01', '2016-12-31', '2017-01-01',
           '2017-04-01', '2017-12-31', '2018-01-01', '2018-04-01', '2019-04-01'].map(&:to_date)
        end

        before do
          EmployeeTimeOffPolicy.order(:effective_at).each do |etop|
            RecreateBalances::AfterEmployeeTimeOffPolicyCreate.new(
              time_off_category_id: etop.time_off_category_id,
              employee_id: etop.employee_id,
              new_effective_at: etop.effective_at
            ).call
          end
          subject
        end

        it { expect(balance_effective_ats).to match_array(expected_balances_dates) }
        it { expect(EmployeeTimeOffPolicy.count).to eq(1) }
      end

      context 'when they are no join tables with the same resources before and after' do
        before { employee_time_off_policy }
        it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-1) }

        it { is_expected.to have_http_status(204) }

        context 'when there is employee balance but its effective at is before resource\'s' do
          let(:employee_balance) do
            create(:employee_balance, :with_time_off, employee: employee,
              effective_at: join_table.effective_at - 5.days)
          end

          it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-1) }

          it { is_expected.to have_http_status(204) }
        end
      end

      context 'when they are join tables with the same resources before and after' do
        let(:id) { same_resource_tables.second }
        let!(:same_resource_tables) do
          [Time.now - 1.week, Time.now, Time.now + 1.week].map do |date|
            create(:employee_time_off_policy,
              employee: employee, time_off_policy: time_off_policy, effective_at: date)
          end
        end

        before do
          EmployeeTimeOffPolicy.order(:effective_at).each do |etop|
            RecreateBalances::AfterEmployeeTimeOffPolicyCreate.new(
              time_off_category_id: etop.time_off_category_id,
              employee_id: etop.employee_id,
              new_effective_at: etop.effective_at
            ).call
          end
        end

        it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-2) }
        it { is_expected.to have_http_status(204) }
      end

      context 'when they are employee balances after employee_time_off_policy effective at' do
        context 'and these are time offs balances' do
          let!(:employee_balance) do
            create(:employee_balance, :with_time_off, employee: employee,
              effective_at: employee_time_off_policy.effective_at + 5.days,
              time_off_category: category)
          end

          before do
            EmployeeTimeOffPolicy.order(:effective_at).each do |etop|
              RecreateBalances::AfterEmployeeTimeOffPolicyCreate.new(
                time_off_category_id: etop.time_off_category_id,
                employee_id: etop.employee_id,
                new_effective_at: etop.effective_at
              ).call
            end
          end

          it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-1) }
          it { is_expected.to have_http_status(204) }
        end

        context 'and these are additions balances' do
          before do
            employee_time_off_policy.policy_assignation_balance.destroy!
            employee_time_off_policy.update!(effective_at: Time.now - 2.years)
            EmployeeTimeOffPolicy.order(:effective_at).each do |etop|
              RecreateBalances::AfterEmployeeTimeOffPolicyCreate.new(
                time_off_category_id: etop.time_off_category_id,
                employee_id: etop.employee_id,
                new_effective_at: etop.effective_at
              ).call
            end
          end

          it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-1) }
          it { is_expected.to have_http_status(204) }
        end
      end
    end

    context 'with invalid params' do
      before { employee_time_off_policy }

      context 'with invalid id' do
        let(:id) { '1ab' }

        it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when EmployeeTimeOffPolicy belongs to other account' do
        before { employee_time_off_policy.employee.update!(account: create(:account)) }

        it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when user is not an account manager' do
        before { Account::User.current.update!(account_manager: false, employee: employee) }

        it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
        it { is_expected.to have_http_status(403) }

        it 'have valid error message' do
          subject

          expect(response.body).to include 'You are not authorized to access this page.'
        end
      end
    end
  end
end
