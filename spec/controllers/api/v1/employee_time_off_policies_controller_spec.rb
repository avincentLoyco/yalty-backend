require 'rails_helper'

RSpec.describe API::V1::EmployeeTimeOffPoliciesController, type: :controller do
  include_context 'shared_context_headers'
  include_context 'shared_context_timecop_helper'

  let!(:category) { create(:time_off_category, account: Account.current) }
  let(:employee) { create(:employee, account: Account.current) }
  let!(:time_off_policy) { create(:time_off_policy, :with_end_date, time_off_category: category) }
  let(:time_off_policy_id) { time_off_policy.id }

  describe 'reset join tables behaviour' do
    include_context 'shared_context_join_tables_controller',
      join_table: :employee_time_off_policy,
      resource: :time_off_policy
  end

  shared_examples 'Proper error response' do
    before { subject }
    it { expect_json_keys('errors.*', %i(field messages status type codes employee_id)) }
    it 'includes employee_id and error code' do
      expect_json('errors.0',
        employee_id: employee.id,
        codes: error_code)
    end
  end

  shared_examples 'TimeOff validity date change when both policies have validity date' do
    let!(:time_off_balance) do
      create(:employee_balance_manual, :with_time_off,
        employee: employee, time_off_category: category, effective_at: time_off_end,
        validity_date: validity_date)
    end
    let!(:removal_for_time_off) do
      create(:employee_balance_manual,
        effective_at: validity_date, employee: employee, time_off_category: category,
        balance_credit_additions: [time_off_balance], balance_type: 'removal')
    end
    let(:balances_after_time_off_flag) do
      Employee::Balance.where('effective_at > ?', time_off_end).pluck(:being_processed).uniq
    end
    let(:validity_date) { RelatedPolicyPeriod.new(etop_2).validity_date_for_balance_at(time_off_end) }

    context 'and they are in the same dates' do
      before do
        ManageEmployeeBalanceAdditions.new(etop_1).call
        subject
      end

      it do
        expect(time_off_balance.reload.validity_date.to_date).to eq(
          RelatedPolicyPeriod.new(etop_1)
          .validity_date_for_balance_at(etop_1.effective_at + 1.year).to_date)
      end
    end

    context 'and they are in different dates' do
      before do
        ManageEmployeeBalanceAdditions.new(etop_1).call
        subject
      end

      it { expect(balances_after_time_off_flag).to eq [true] }
      it { expect(Employee::Balance.exists?(removal_for_time_off.id)).to eq false }
      it do
        expect(time_off_balance.reload.validity_date.to_date).to eq(
          RelatedPolicyPeriod.new(etop_1)
          .validity_date_for_balance_at(etop_1.effective_at + 1.year).to_date)
      end
      it do
        expect(time_off_balance.reload.balance_credit_removal_id)
          .to_not eq(removal_for_time_off.id)
      end
    end
  end

  shared_examples "TimeOff validity date change when one policy does not have validity date" do
    let!(:time_off_balance) do
      create(:employee_balance_manual, :with_time_off,
        employee: employee, time_off_category: category, effective_at: time_off_end,
        validity_date: validity_date)
    end
    let!(:removal_for_time_off) do
      create(:employee_balance_manual,
        effective_at: validity_date, employee: employee, time_off_category: category,
        balance_credit_additions: [time_off_balance], balance_type: 'removal')
    end
    let(:balances_after_time_off_flag) do
      Employee::Balance.where('effective_at > ?', time_off_end).pluck(:being_processed).uniq
    end
    let(:validity_date) { RelatedPolicyPeriod.new(etop_2).validity_date_for_balance_at(time_off_end) }

    context 'previous policy does not have validity date' do
      before do
        time_off_policy.update!(end_day: nil, end_month: nil)
        ManageEmployeeBalanceAdditions.new(etop_1).call
        subject
      end

      it { expect(balances_after_time_off_flag).to eq [true] }
      it { expect(time_off_balance.reload.validity_date).to eq nil }
      it { expect(time_off_balance.reload.balance_credit_removal_id).to eq nil }
      it { expect(Employee::Balance.exists?(removal_for_time_off.id)).to eq false }
    end

    context 'current policy does not have validity date' do
      before do
        top_b.update!(end_day: nil, end_month: nil)
        time_off_balance.update!(balance_credit_removal_id: nil, validity_date: nil)
        removal_for_time_off.destroy!
        ManageEmployeeBalanceAdditions.new(etop_1).call
        subject
      end

      it { expect(balances_after_time_off_flag).to eq [true] }
      it { expect(time_off_balance.reload.validity_date).to_not eq nil }
      it { expect(time_off_balance.reload.balance_credit_removal_id).to_not eq nil }
      it { expect(time_off_balance.reload.balance_credit_removal).to_not be nil }
    end
  end

  shared_examples "TimeOff validity date when both policies does not have validity dates" do
    let!(:time_off_balance) do
      create(:employee_balance_manual, :with_time_off,
        employee: employee, time_off_category: category, effective_at: time_off_end,
        validity_date: validity_date)
    end
    let!(:removal_for_time_off) do
      create(:employee_balance_manual,
        effective_at: validity_date, employee: employee, time_off_category: category,
        balance_credit_additions: [time_off_balance], balance_type: 'removal')
    end
    let(:balances_after_time_off_flag) do
      Employee::Balance.where('effective_at > ?', time_off_end).pluck(:being_processed).uniq
    end
    let(:validity_date) { RelatedPolicyPeriod.new(etop_2).validity_date_for_balance_at(time_off_end) }

    before do
      top_b.update!(end_day: nil, end_month: nil)
      top_a.update!(end_day: nil, end_month: nil)
      time_off_balance.update!(validity_date: nil, balance_credit_removal_id: nil)
      removal_for_time_off.destroy!
      ManageEmployeeBalanceAdditions.new(etop_1).call
      subject
    end

    it { expect(time_off_balance.reload.validity_date).to eq nil }
    it { expect(time_off_balance.reload.balance_credit_removal_id).to eq nil }
    it { expect(time_off_balance.reload.balance_credit_removal).to be nil }
  end

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
      before { Account::User.current.update!(role: 'user') }

      it { is_expected.to have_http_status(403) }
    end
  end

  describe 'POST #create' do
    subject { post :create, params }
    let(:effective_at) { Time.now - 1.day }
    let(:params) do
      {
        employee_id: employee.id,
        time_off_policy_id: time_off_policy_id,
        effective_at: effective_at
      }
    end

    context 'with valid params' do
      it { expect { subject }.to change { employee.employee_time_off_policies.count }.by(1) }
      it { expect { subject }.to change { Employee::Balance.additions.count }.by(3) }
      it { expect { subject }.to change { Employee::Balance.count }.by(11) }

      it { is_expected.to have_http_status(201) }

      context 'response body' do
        before { subject }

        it do
          expect_json_keys(
            [:id, :type, :assignation_type, :effective_at, :assignation_id, :employee_balance])
        end
        it { expect_json(id: employee.id, effective_till: nil) }
      end

      context 'when effective at is in the future and before is reset policy' do
        before do
          create(:employee_time_off_policy, :with_employee_balance,
            effective_at: employee.hired_date, employee: employee, time_off_policy: time_off_policy)
          create(:employee_event,
            employee: employee, event_type: 'contract_end', effective_at: 1.week.ago)
        end
        let!(:rehired) do
          create(:employee_event,
            employee: employee, effective_at: 2.years.since, event_type: 'hired')
        end

        let(:effective_at) { 2.years.since }

        it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(1) }
        it { expect { subject }.to change { Employee::Balance.count }.by(2) }
        it { is_expected.to have_http_status(201) }

        context 'when new effective at one day after contract end' do
          before do
            rehired.update!(effective_at: 6.days.ago)
            params[:effective_at] = 6.days.ago
          end

          it { expect { subject }.to change { EmployeeTimeOffPolicy.not_reset.count }.by(1) }
          it { expect { subject }.to change { EmployeeTimeOffPolicy.with_reset.count }.by(-1) }
          it do
            expect { subject }
              .to_not change { Employee::Balance.where(balance_type: 'reset').count }
          end

          it { is_expected.to have_http_status(201) }
        end
      end

      context 'when creating etop in place of another' do
        let(:effective_at) { Date.new(2016, 1, 1) }
        let(:top_a) { time_off_policy }
        let(:top_b) do
          create(:time_off_policy, time_off_category: category, end_day: 1, end_month: 5,
            years_to_effect: 1, start_month: 2)
        end
        let!(:etop_1) do
          create(:employee_time_off_policy, time_off_policy: top_a, employee: employee,
            effective_at: Time.zone.parse('2015-01-01'))
        end
        let!(:etop_2) do
          create(:employee_time_off_policy, time_off_policy: top_b, employee: employee,
            effective_at: Time.zone.parse('2016-01-01'))
        end
        let(:balance_effective_ats) { Employee::Balance.pluck(:effective_at).map(&:to_date) }
        let(:time_off_end) { 1.week.since }

        it_behaves_like "TimeOff validity date change when both policies have validity date"
        it_behaves_like "TimeOff validity date change when one policy does not have validity date"
        it_behaves_like "TimeOff validity date when both policies does not have validity dates"

        context 'and there is time off after first etop effective at' do
          before { etop_2.destroy! }

          let!(:time_off) do
            create(:time_off,
              employee: employee, time_off_category: category, end_time: Date.new(2015, 6, 6),
              start_time: Date.new(2015, 6, 5))
          end
          let(:time_off_policy_id) { top_b.id }
          let(:effective_at) { Date.new(2015, 1, 1) }

          it { expect { subject }.to_not change { TimeOff.count } }
          it { expect { subject }.to_not change { EmployeeTimeOffPolicy } }
          it do
            expect { subject }.to change { employee.reload.employee_time_off_policies.pluck(:id) }
          end
          it do
            expect { subject }
              .to change { employee.reload.employee_time_off_policies.pluck(:time_off_policy_id) }
              .to include (top_b.id)
          end

          it { is_expected.to have_http_status(201) }

          context 'when the same resource assigned' do
            let(:time_off_policy_id) { top_a.id }
            let(:error_code) do
              ['effective_at_join_table_with_given_date_and_resource_already_exists']
            end

            it { expect { subject }.to_not change { TimeOff.count } }
            it { expect { subject }.to_not change { EmployeeTimeOffPolicy } }
            it do
              expect { subject }
                .to_not change { employee.reload.employee_time_off_policies.pluck(:id) }
            end
            it do
              expect { subject }.to_not change {
                employee.reload.employee_time_off_policies.pluck(:time_off_policy_id) }
            end
            it { is_expected.to have_http_status(422) }
            it_behaves_like 'Proper error response'
          end
        end

        context 'it removes duplicated etops and recreate balances' do
          let(:expected_balances_dates) do
            %w(2015-01-01 2016-01-01 2016-01-01 2016-04-02 2017-01-01
               2017-01-01 2017-04-02 2018-01-01 2018-01-01 2018-04-02 2019-04-02).map(&:to_date)
          end

          before do
            ManageEmployeeBalanceAdditions.new(etop_1).call
            subject
          end

          it { expect(EmployeeTimeOffPolicy.count).to eq(2) }
          it { expect(balance_effective_ats).to match_array(expected_balances_dates) }
        end
      end

      context 'when policy effective at is in the past' do
        before { time_off_policy.update!(end_month: 4, end_day: 1, years_to_effect: 2) }

        let(:effective_at) { 1.years.ago - 1.day }

        it { expect { subject }.to change { employee.employee_time_off_policies.count }.by(1) }
        it { expect { subject }.to change { employee.employee_balances.additions.uniq.count }.by(5) }
        it { expect { subject }.to change { employee.employee_balances.removals.uniq.count }.by(6) }
        it { expect { subject }.to change { employee.reload.employee_balances.count }.by(17) }

        it { is_expected.to have_http_status(201) }

        context 'and assignation and date is at policy start date' do
          let(:effective_at) { 1.years.ago }

          it { expect { subject }.to change { employee.employee_time_off_policies.count }.by(1) }
          it { expect { subject }.to change { employee.employee_balances.count }.by(14) }

          it { is_expected.to have_http_status(201) }
        end
      end

      context 'with adjustment_balance_amount param given' do
        before { params.merge!(employee_balance_amount: 1000) }
        let(:effective_at) { 1.day.ago }

        it { expect { subject }.to change { Employee::Balance.count }.by(11) }
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

          it { expect(new_balances.second.balance_type).to eq 'end_of_period' }
          it { expect(new_balances.additions.last.amount).to eq time_off_policy.amount }
          it { expect(new_balances.first.balance_type).to eq 'assignation' }
          it { expect(new_balances.first.manual_amount).to eq params[:employee_balance_amount] }

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
              time_off_category: time_off_policy.time_off_category, updated_at: 30.minutes.ago)
          end

          context 'after effective at' do
            let!(:related_effective_at) { 1.years.since }

            it { is_expected.to have_http_status(201) }
            it do
              expect { subject }.to_not change { EmployeeTimeOffPolicy.exists?(related_resource.id) }
            end
            it do
              expect { subject }.to_not change { related_balance.updated_at }
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
            let(:related_effective_at) { 1.years.ago }

            before do
              EmployeeTimeOffPolicy.order(:effective_at).each do |etop|
                RecreateBalances::AfterEmployeeTimeOffPolicyCreate.new(
                  time_off_category_id: etop.time_off_category_id,
                  employee_id: etop.employee_id,
                  new_effective_at: etop.effective_at
                ).call
              end
            end

            it { is_expected.to have_http_status(201) }

            it { expect { subject }.to change { Employee::Balance.count }.by(1) }
            it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(1) }
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
          it { expect { subject }.to change { Employee::Balance.count }.by(11) }
        end
      end

      context 'when one ETOP of the same category already exists with assignation on the same day' do
        let!(:past_etop) do
          create(:employee_time_off_policy, employee: employee, time_off_policy: time_off_policy,
            effective_at: effective_at)
        end

        context "and it's policy is the same as the policy as the ETOP being created" do
          let(:employee_id) { employee.id}
          let(:error_code) do
            ['effective_at_join_table_with_given_date_and_resource_already_exists']
          end

          it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
          it { expect { subject }.to_not change { Employee::Balance.count } }

          it { is_expected.to have_http_status(422) }
          it_behaves_like 'Proper error response'
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
          ManageEmployeeBalanceAdditions.new(first_etop).call
        end

        context 'and the effective at is equal to the latest ETOP effective_at' do
          let(:effective_at) { latest_etop.effective_at }

          context 'and the time off policy is the same as the oldest ETOP' do
            before { create_balances_for_existing_etops }

            it { expect { subject }.not_to change { EmployeeTimeOffPolicy.count } }
            it { expect { subject }.to change { Employee::Balance.count }.by(2) }

            it { is_expected.to have_http_status(201) }
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
            it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.from(2).to(3) }
            it { expect { subject }.to_not change { EmployeeTimeOffPolicy.exists?(latest_etop.id) } }
            it { expect { subject }.to change { Employee::Balance.count } }
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
        before { Account::User.current.update!(role: 'user') }

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
      let(:error_code) { ['effective_at_cant_be_set_outside_of_employee_contract_period'] }

      it { expect(response.body).to include 'can\'t be set outside of employee contract period' }

      it { is_expected.to have_http_status(422) }
      it_behaves_like 'Proper error response'
    end

    context 'when hired and contract end in the same date' do
      before do
        create(:employee_time_off_policy,
          employee: employee, time_off_policy: time_off_policy, effective_at: employee.hired_date)
        create(:employee_event,
          employee: employee, event_type: 'contract_end', effective_at: employee.hired_date)
      end
      let(:effective_at) { employee.hired_date + 1.day }

      context 'when employee had assignations' do
        let(:error_code) { ["effective_at_can_not_assign_in_reset_resource_effective_at"] }
        before { subject }

        it { expect(response.body).to include 'Can not assign in reset resource effective at' }

        it { is_expected.to have_http_status(422) }
        it_behaves_like 'Proper error response'
      end

      context 'when employee does not have assignations' do
        let(:error_code) { ['effective_at_cant_be_set_outside_of_employee_contract_period'] }
        before do
          EmployeeTimeOffPolicy.destroy_all
          subject
        end

        it { expect(response.body).to include 'can\'t be set outside of employee contract period' }

        it { is_expected.to have_http_status(422) }
        it_behaves_like 'Proper error response'
      end
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
          let(:time_off_end) { Date.new(2014, 1, 8) }
          let!(:etop_1) do
            create(:employee_time_off_policy, time_off_policy: top_a, employee: employee,
              effective_at: Time.zone.parse('2013-01-01'))
          end
          let!(:etop_2) do
            create(:employee_time_off_policy, time_off_policy: top_b, employee: employee,
              effective_at: Time.zone.parse('2014-01-01'))
          end

          it_behaves_like "TimeOff validity date change when both policies have validity date"
          it_behaves_like "TimeOff validity date change when one policy does not have validity date"
          it_behaves_like "TimeOff validity date when both policies does not have validity dates"


          context 'it creates proper balances' do
            let(:expected_balances_dates) do
              %w(2013-01-01 2014-01-01 2014-01-01 2014-04-02 2015-01-01
                 2015-01-01 2015-04-02 2016-01-01 2016-01-01 2016-04-02 2017-01-01 2017-01-01
                 2017-04-02 2018-01-01 2018-01-01 2018-04-02 2019-04-02).map(&:to_date)
            end

            before do
              ManageEmployeeBalanceAdditions.new(etop_1).call
              subject
            end

            it { expect(balance_effective_ats).to match_array(expected_balances_dates) }
            it { expect(EmployeeTimeOffPolicy.count).to eq(2) }
          end

          context 'when new effective_at is one day after contract end' do
            let(:effective_at) { '31/12/2013' }

            before do
              create(:employee_event,
                employee: employee, event_type: 'contract_end', effective_at: '30/12/2013')
              create(:employee_event,
                employee: employee, event_type: 'hired', effective_at: '31/12/2013')
            end

            context 'and there is join table with different resource after' do
              it { expect { subject }.to change { EmployeeTimeOffPolicy.with_reset.count }.by(-1) }
              it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-1) }
              it { expect { subject }.to change { join_table_resource.reload.effective_at } }

              it do
                expect { subject }
                  .to_not change { Employee::Balance.where(balance_type: 'reset').count }
              end
              it { is_expected.to have_http_status(200) }
            end

            context 'and there is join table with the same resource after' do
              before { etop_2.update!(time_off_policy: top_a) }

              let!(:duplicated_etops) do
                [-2, 2].map do |day|
                  create(:employee_time_off_policy,
                    employee: employee, time_off_policy: top_b,
                    effective_at: join_table_resource.effective_at + day.days)
                end
              end

              it { expect { subject }.to change { EmployeeTimeOffPolicy.with_reset.count }.by(-1) }
              it { expect { subject }.not_to change { EmployeeTimeOffPolicy.not_reset.count } }
              it { expect { subject }.not_to change { EmployeeTimeOffPolicy.exists?(etop_2.id) } }
              it { expect { subject }.to change { join_table_resource.reload.effective_at } }
              it do
                expect { subject }
                  .to_not change { Employee::Balance.where(balance_type: 'reset').count }
              end
              it do
                expect { subject }
                  .not_to change { EmployeeTimeOffPolicy.exists?(duplicated_etops.last.id) }
              end

              it { is_expected.to have_http_status(200) }
            end
          end
        end

        context 'to future' do
          let(:effective_at) { Date.new(2017, 1, 1) }
          let!(:etops_b) do
            [
              Time.zone.parse('2014-01-01'), Time.zone.parse('2016-01-01'),
              Time.zone.parse('2018-01-01')
            ].map do |date|
              create(:employee_time_off_policy, time_off_policy: top_b, employee: employee,
                effective_at: date)
            end
          end
          let!(:etops_a) do
            [Time.zone.parse('2013-01-01'), Time.zone.parse('2017-01-01')].map do |date|
              create(:employee_time_off_policy,
                time_off_policy: top_a, employee: employee, effective_at: date)
            end
          end
          let(:id) { etops_b.first }
          let(:etop_1) { etops_a.first }
          let(:etop_2) { etops_b.first }
          let(:time_off_end) { Date.new(2014, 1, 8) }

          it_behaves_like "TimeOff validity date change when both policies have validity date"
          it_behaves_like "TimeOff validity date when both policies does not have validity dates"

          context 'it creates proper balances' do
            let(:expected_balances_dates) do
              %w(2013-01-01 2014-01-01 2014-01-01 2014-04-02 2015-01-01
                 2015-01-01 2015-04-02 2016-01-01 2016-02-01 2016-02-01 2016-04-02 2016-05-02
                 2017-01-01 2017-01-01 2017-02-01 2017-02-01 2017-05-02 2018-05-02).map(&:to_date)
            end

            before do
              ManageEmployeeBalanceAdditions.new(etops_a.first).call
              subject
            end

            it { expect(balance_effective_ats).to match_array(expected_balances_dates) }
            it { expect(EmployeeTimeOffPolicy.count).to eq(5) }
          end

          context 'when previous effective at was one day after contract end day' do
            before do
              create(:employee_event,
                event_type: 'contract_end', employee: employee, effective_at: '31/12/2013')
              create(:employee_event,
                event_type: 'hired', employee: employee, effective_at: '1/1/2014')
            end

            context 'and there are no duplicated etops after change' do
              it { expect { subject }.to change { EmployeeTimeOffPolicy.not_reset.count }.by(-1) }
              it { expect { subject }.to change { EmployeeTimeOffPolicy.with_reset.count }.by(1) }
              it do
                expect { subject }.not_to change { EmployeeTimeOffPolicy.exists?(etops_b.last.id) }
              end
              it do
                expect { subject }.not_to change { EmployeeTimeOffPolicy.exists?(etops_b.first.id) }
              end
              it do
                expect { subject }.to change { EmployeeTimeOffPolicy.exists?(etops_a.second.id) }
              end

              it do
                expect { subject }.to_not change { EmployeeTimeOffPolicy.exists?(etops_b.second.id) }
              end
              it { is_expected.to have_http_status(200) }
            end
          end
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
            effective_at: join_table_resource.effective_at + Employee::Balance::ASSIGNATION_OFFSET,
            manual_amount: 2000,
            balance_type: 'assignation'
          )
        end

        it { expect { subject }.to change { join_table_resource.reload.effective_at } }
        it { expect { subject }.to change { Employee::Balance.count }.by(13) }
        it { is_expected.to have_http_status(200) }

        it 'affects assignation balance' do
          subject
          addition_balance = Employee::Balance.additions.first

          expect(assignation_balance.effective_at.to_date).to eq(effective_at)
          expect(addition_balance.resource_amount).to eq(time_off_policy.amount)
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
        let(:expected_balances_dates) do
          %w(2014-01-01 2015-01-01 2015-01-01 2015-04-02 2016-01-01 2016-01-01 2016-04-02
             2017-01-01 2017-01-01 2017-04-02 2018-01-01 2018-01-01 2018-04-02 2019-04-02
             ).map(&:to_date)
        end

        it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
        it { expect { subject }.to change { Employee::Balance.count }.by(14) }
        it { expect { subject }.to change { Employee::Balance.additions.count }.by(4) }

        it { expect { subject }.to change { join_table_resource.reload.effective_at } }

        it 'should create employee balances with proper effective at' do
          subject

          expect(Employee::Balance.all.order(:effective_at).pluck(:effective_at).map(&:to_date))
            .to eq(expected_balances_dates)
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
          let(:error_code) do
            ['effective_at_join_table_with_given_date_and_resource_already_exists']
          end

          it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }

          it { is_expected.to have_http_status(422) }
          it_behaves_like 'Proper error response'
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
            it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-1) }
            it { expect { subject }.to change { EmployeeTimeOffPolicy.exists?(latest_etop.id) } }
            it { expect { subject }.not_to change { EmployeeTimeOffPolicy.exists?(first_etop.id) } }
            it { expect { subject }.not_to change { EmployeeTimeOffPolicy.exists?(id) } }
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
            it { expect { subject }.not_to change { EmployeeTimeOffPolicy.count } }
            it { expect { subject }.not_to change { EmployeeTimeOffPolicy.exists?(id) } }

            it { is_expected.to have_http_status(200) }

            context 'and employee time off policy has assignation balance' do
              let!(:employee_balance) do
                create(
                  :employee_balance_manual,
                  time_off_category: category,
                  employee: employee,
                  effective_at: join_table_resource.effective_at +
                                Employee::Balance::ASSIGNATION_OFFSET,
                  balance_type: 'assignation',
                  manual_amount: 2000)
              end

              it { is_expected.to have_http_status(200) }

              it { expect { subject }.not_to change { EmployeeTimeOffPolicy.count } }
              it { expect { subject }.not_to change { EmployeeTimeOffPolicy.exists?(id) } }
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

          before { ManageEmployeeBalanceAdditions.new(first_etop).call }

          context 'and the time off policy is the same as the latest ETOP' do
            before { join_table_resource.update!(time_off_policy: latest_etop.time_off_policy) }

            it { expect { subject }.not_to change { EmployeeTimeOffPolicy.count } }
            it { expect { subject }.not_to change { EmployeeTimeOffPolicy.exists?(id) } }

            it { is_expected.to have_http_status(200) }
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
      context 'when there is time off employee balance and no policy before' do
        before do
          create(:time_off,
            time_off_category: category, employee: employee, end_time: time_off_effective_at,
            start_time: time_off_effective_at - 2.days)
        end

        context 'after old effective_at' do
          let(:effective_at) { 5.years.since }
          let(:time_off_effective_at) { 2.days.since }
          let(:error_code) do
            ['effective_at_cant_change_if_there_are_time_offs_after_and_there_is_no_previous_policy']
          end

          it { expect { subject }.to_not change { join_table_resource.reload.effective_at } }

          it 'returns valid response' do
            subject

            expect(response.body).to include(
              "Can't change if there are time offs after and there is no previous policy"
            )
          end

          it { is_expected.to have_http_status(422) }
          it_behaves_like 'Proper error response'
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
        let(:error_code) { ['effective_at_join_table_with_given_date_and_resource_already_exists'] }

        it { expect { subject }.to_not change { join_table_resource.reload.effective_at } }

        it { is_expected.to have_http_status(422) }
        it_behaves_like 'Proper error response'
      end

      context 'when user is not account manager' do
        before { Account::User.current.update!(role: 'user', employee: employee) }

        it { expect { subject }.to_not change { join_table_resource.reload.effective_at } }
        it { is_expected.to have_http_status(403) }
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:employee_time_off_policy) do
      create(:employee_time_off_policy, :with_employee_balance,
        employee: employee, time_off_policy: time_off_policy, effective_at: Time.zone.now)
    end
    let(:id) { employee_time_off_policy.id }

    subject { delete :destroy, id: id }

    context 'with valid params' do
      context 'when removing etop between the same etops' do
        let(:id) { etop_2.id }
        let(:top_a) { time_off_policy }
        let(:top_b) do
          create(:time_off_policy, time_off_category: category, end_day: 1, end_month: 5,
            years_to_effect: 1, start_month: 2)
        end
        let!(:etops_1) do
          [Time.zone.parse('2013-01-01'), Time.zone.parse('2015-01-01')].map do |date|
            create(:employee_time_off_policy, :with_employee_balance,
              time_off_policy: top_a, employee: employee, effective_at: date)
          end
        end
        let!(:etop_2) do
          create(:employee_time_off_policy, :with_employee_balance,
            time_off_policy: top_b, employee: employee,
            effective_at: Time.zone.parse('2014-01-01'))
        end
        let(:balance_effective_ats) { Employee::Balance.pluck(:effective_at).map(&:to_date) }
        let(:etop_1) { etops_1.first }
        let(:time_off_end) { 2.years.ago + 1.week }

        it_behaves_like "TimeOff validity date change when both policies have validity date"
        it_behaves_like "TimeOff validity date change when one policy does not have validity date"
        it_behaves_like "TimeOff validity date when both policies does not have validity dates"

        context 'it removes duplicated etops and recreate balances' do
          let(:expected_balances_dates) do
            %w(2013-01-01 2014-01-01 2014-01-01 2014-04-02 2015-01-01
               2015-01-01 2015-04-02 2016-01-01 2016-01-01 2016-04-02 2017-01-01 2017-01-01
               2017-04-02 2018-01-01 2018-01-01 2018-04-02 2019-04-02).map(&:to_date)
          end
          before do
            ManageEmployeeBalanceAdditions.new(etop_1).call
            subject
          end

          it { expect(EmployeeTimeOffPolicy.count).to eq(2) }
          it { expect(balance_effective_ats).to match_array(expected_balances_dates) }
        end

        context 'when there is contract end day before removed resource' do
          before do
            create(:employee_event,
              event_type: 'contract_end', employee: employee, effective_at: etop_2.effective_at - 1)
            create(:employee_event,
              event_type: 'hired', employee: employee, effective_at: etop_2.effective_at)
          end

          it { expect { subject }.to change { EmployeeTimeOffPolicy.not_reset.count }.by(-1) }
          it { expect { subject }.to change { EmployeeTimeOffPolicy.exists?(etop_2.id) } }
          it { expect { subject }.to change { EmployeeTimeOffPolicy.with_reset.count }.by(1) }

          it { is_expected.to have_http_status(204) }
        end
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

        before { ManageEmployeeBalanceAdditions.new(same_resource_tables.first).call }

        it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-1) }
        it { is_expected.to have_http_status(204) }
      end

      context 'when they are employee balances after employee_time_off_policy effective at' do
        context 'and these are time offs balances' do
          let!(:employee_balance) do
            create(:employee_balance, :with_time_off, employee: employee,
              effective_at: employee_time_off_policy.effective_at + 5.days,
              time_off_category: category)
          end
          let(:error_code) do
            ['effective_at_cant_remove_if_there_are_time_offs_after_and_there_is_no_previous_policy']
          end

          before { ManageEmployeeBalanceAdditions.new(employee_time_off_policy).call }

          it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
          it do
            subject

            expect(response.body).to include(
              'Can\'t remove if there are time offs after and there is no previous policy'
            )
          end

          it { is_expected.to have_http_status(403) }
          it_behaves_like 'Proper error response'
        end

        context 'and these are additions balances' do
          before do
            employee_time_off_policy.policy_assignation_balance.destroy!
            employee_time_off_policy.update!(effective_at: Time.now - 2.years)
            ManageEmployeeBalanceAdditions.new(employee_time_off_policy).call
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
        before { Account::User.current.update!(role: 'user', employee: employee) }

        it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
        it { is_expected.to have_http_status(403) }

        it 'have valid error message' do
          subject

          expect(response.body).to include 'You are not authorized to access this page.'
        end
      end
    end

    context 'when there is contract_end' do
      let!(:contract_end) do
        create(:employee_event, employee: employee, effective_at: 3.months.from_now,
          event_type: 'contract_end')
      end
      let(:reset_top) do
        create(:time_off_policy, time_off_category: category, policy_type: nil, reset: true)
      end
      let(:reset_etop) do
        create(:employee_time_off_policy, employee: employee, time_off_policy: reset_top,
          effective_at: contract_end.effective_at + 1.day)
      end

      context 'only one employee_time_off_policy' do
        before do
          employee_time_off_policy
          reset_etop
        end

        it { expect { subject }.to change(EmployeeTimeOffPolicy, :count).by(-2) }
      end

      context 'there are employee_time_off_policies left' do
        let(:top) do
          create(:time_off_policy, time_off_category: category, policy_type:
            time_off_policy.policy_type)
        end
        let(:etop_2) do
          create(:employee_time_off_policy, :with_employee_balance, employee: employee,
            time_off_policy: top, effective_at: 1.month.from_now)
        end

        before do
          employee_time_off_policy
          etop_2
          reset_etop
        end

        it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-1) }
      end
    end
  end
end
