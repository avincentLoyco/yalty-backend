require "rails_helper"

RSpec.describe API::V1::EmployeePresencePoliciesController, type: :controller do
  include_context "shared_context_headers"
  include_context "shared_context_timecop_helper"

  shared_examples "Proper error response" do
    before { subject }
    it { expect_json_keys("errors.*", %i(field messages status type codes employee_id)) }
    it "includes employee_id and error code" do
      expect_json("errors.0",
        employee_id: employee.id,
        codes: error_code)
    end
  end

  let(:presence_policy) { create(:presence_policy, :with_presence_day, account: account) }
  let(:employee) { create(:employee, account: Account.current) }
  let(:presence_policy_id) { presence_policy.id }
  let(:contract_end) do
    create(:employee_event,
      event_type: "contract_end", employee: employee, effective_at: contract_end_date)
  end
  let(:rehired) do
    create(:employee_event,
      event_type: "hired", employee: employee, effective_at: contract_end_date + 1.day)
  end

  describe "reset join tables behaviour" do
    include_context "shared_context_join_tables_controller",
      join_table: :employee_presence_policy,
      resource: :presence_policy
  end

  describe "GET #index" do
    subject { get :index, presence_policy_id: presence_policy.id }

    let(:new_policy) { create(:presence_policy, account: account) }
    let!(:epp) do
      create(:employee_presence_policy, employee: employee, effective_at: 7.days.since)
    end
    let!(:epps) do
      [3.days.ago, 1.day.ago, 5.days.since].map do |day|
        create(:employee_presence_policy,
          presence_policy: presence_policy, employee: employee, effective_at: day
        )
      end
    end

    context "with valid params" do
      it "has valid keys in json" do
        subject

        expect_json_keys(
          "*",
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

      context "when no filter param given" do
        it { is_expected.to have_http_status(200) }

        it "has valid employee presence policies in response" do
          subject

          expect(response.body).to include(epps.second.id, epps.last.id)
          expect(response.body).to_not include(epps.first.id, epp.id)
        end
      end

      context "when filter active param given" do
        subject { get :index, presence_policy_id: presence_policy.id, filter: "active" }

        it { is_expected.to have_http_status(200) }

        it "has valid employee presence policies in response" do
          subject

          expect(response.body).to include(epps.second.id, epps.last.id)
          expect(response.body).to_not include(epps.first.id, epp.id)
        end
      end

      context "when filter inactive param given" do
        subject { get :index, presence_policy_id: presence_policy.id, filter: "inactive" }

        it { is_expected.to have_http_status(200) }

        it "has valid employee presence policies in response" do
          subject

          expect(response.body).to include(epps.first.id)
          expect(response.body).to_not include(epps.second.id, epps.last.id, epp.id)
        end
      end

      context "when filter all param given" do
        subject { get :index, presence_policy_id: presence_policy.id, filter: "all" }

        it { is_expected.to have_http_status(200) }

        it "has valid employee presence policies in response" do
          subject

          expect(response.body).to include(epps.first.id, epps.second.id, epps.last.id)
          expect(response.body).to_not include(epp.id)
        end
      end
    end

    context "with invalid params" do
      context "with invalid presence_policy" do
        subject { get :index, presence_policy_id: "1" }

        it { is_expected.to have_http_status(404) }
      end

      context "when presence policy does not belongs to current account" do
        before { Account.current = create(:account) }

        it { is_expected.to have_http_status(404) }
      end

      context "when current account is not account manager" do
        before { Account::User.current.update!(role: "user") }

        it { is_expected.to have_http_status(403) }
      end
    end
  end

  describe "POST #create" do
    subject { post :create, params }

    let(:params) do
      {
        employee_id: employee.id,
        presence_policy_id: presence_policy_id,
        effective_at: effective_at,
        order_of_start_day: 1
      }
    end

    let(:effective_at) { Time.zone.today }
    let(:new_policy_id) { create(:presence_policy, :with_presence_day, account: account).id }

    context "with valid params" do
      it { expect { subject }.to change { employee.employee_presence_policies.count }.by(1) }

      it { is_expected.to have_http_status(201) }

      context "response body" do
        before { subject }

        it { expect_json(id: employee.id, effective_till: nil) }
        it "" do
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

      context "when there is contract end in the future" do
        context "and this is first employee contract end" do
          before do
            create(:employee_event,
              employee: employee, event_type: "contract_end", effective_at: 1.week.since)
          end

          it { expect { subject }.to change { EmployeePresencePolicy.count }.by(2) }
          it { expect { subject }.to change { EmployeePresencePolicy.with_reset.count }.by(1) }
          it { expect { subject }.to change { EmployeePresencePolicy.not_reset.count }.by(1) }
          it { is_expected.to have_http_status(201) }
        end

        context "and employee is rehired" do
          before do
            create(:employee_presence_policy,
              employee: employee, presence_policy: presence_policy, effective_at: 1.week.ago)
            create(:employee_event,
              event_type: "contract_end", effective_at: 1.week.since, employee: employee)
            create(:employee_event,
              event_type: "hired", employee: employee, effective_at: 1.month.since)
            create(:employee_event,
              event_type: "contract_end", effective_at: 2.months.since, employee: employee)
          end

          let(:effective_at) { 1.month.since }

          it { expect { subject }.to change { EmployeePresencePolicy.count }.by(2) }
          it { expect { subject }.to change { EmployeePresencePolicy.with_reset.count }.by(1) }
          it { expect { subject }.to change { EmployeePresencePolicy.not_reset.count }.by(1) }

          it { is_expected.to have_http_status(201) }
        end
      end

      context "when there are emloyee balances with time offs assigned" do
        let(:policy) { create(:time_off_policy) }
        let(:employee_policy) do
          create(:employee_time_off_policy, employee: employee, effective_at: 2.years.ago)
        end
        let!(:balances) do
          [2.months.ago, 2.months.since].map do |date|
            create(:employee_balance_manual, :with_time_off,
              employee: employee, effective_at: date, time_off_category: policy.time_off_category)
          end
        end

        context "when contract end one day before" do
          let(:contract_end_date) { effective_at - 1.day }

          context "and in previous period no join tables were assigned" do
            before do
              contract_end
              rehired
            end

            it { expect { subject }.to change { EmployeePresencePolicy.count }.by(1) }

            it { is_expected.to have_http_status(201) }
          end

          context "and in previous period join tables were assigned" do
            let!(:epp) do
              create(:employee_presence_policy,
                employee: employee, presence_policy: presence_policy, effective_at: 2.years.ago)
            end
            before do
              contract_end
              rehired
            end

            it { expect { subject }.to change { EmployeePresencePolicy.not_reset.count }.by(1) }
            it { expect { subject }.to change { EmployeePresencePolicy.with_reset.count }.by(-1) }
            it do
              expect { subject }
                .to_not change { Employee::Balance.where(balance_type: "reset").count }
            end

            it { is_expected.to have_http_status(201) }

            context "when join table with the same resource assigned in the future" do
              let!(:duplicated_table) do
                create(:employee_presence_policy,
                  employee: employee, presence_policy: presence_policy, effective_at: 2.years.since)
              end

              it { is_expected.to have_http_status(201) }

              it { expect { subject }.to change { EmployeePresencePolicy.not_reset.count }.to(3) }
              it { expect { subject }.to change { EmployeePresencePolicy.with_reset.count }.by(-1) }
              it do
                expect { subject }.not_to change { EmployeePresencePolicy.exists?(duplicated_table.id) }
              end
            end
          end
        end

        context "and new resource was created" do
          context "and there are balances after" do
            it { expect { subject }.to change { balances.last.reload.being_processed} }
            it { expect { subject }.to_not change { balances.first.reload.being_processed } }

            it { expect { subject }.to have_enqueued_job(UpdateBalanceJob).exactly(1) }
            it { is_expected.to have_http_status(201) }
          end

          context "and there is no balances after" do
            let(:effective_at) { 4.months.since }

            it { expect { subject }.to_not change { balances.last.reload.being_processed } }
            it { expect { subject }.to_not change { balances.first.reload.being_processed } }

            it { expect { subject }.to_not have_enqueued_job(UpdateBalanceJob) }
            it { is_expected.to have_http_status(201) }
          end
        end

        context "and new resource was not created" do
          before do
            create(:employee_presence_policy,
              employee: employee, effective_at: 4.months.ago, presence_policy: presence_policy)
          end

          it { expect { subject }.to change { balances.last.reload.being_processed } }
          it { expect { subject }.to_not change { balances.first.reload.being_processed } }

          it { expect { subject }.to have_enqueued_job(UpdateBalanceJob).exactly(1) }
          it { is_expected.to have_http_status(201) }
        end
      end

      context "when at least 2 EPPs exist on the past" do
        let!(:first_epp) do
          create(:employee_presence_policy, employee: employee, presence_policy: presence_policy,
            effective_at: Date.today
          )
        end
        let!(:latest_epp) do
          create(:employee_presence_policy, employee: employee, effective_at: Date.today + 1.week)
        end

        context "and the effective at is equal to the latest EPP effective_at" do
          let(:effective_at) { latest_epp.effective_at }

          context "and the presence policy is the same as the oldest EPP" do
            it { expect { subject }.not_to change { EmployeePresencePolicy.count } }
            it { expect { subject }.to change { EmployeePresencePolicy.exists?(latest_epp.id) } }

            it { is_expected.to have_http_status(201) }
          end

          context "and the presence policy is different than the exisitng EPP's ones" do
            let(:presence_policy_id) { new_policy_id }

            it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
            it { expect { subject }.to change { EmployeePresencePolicy.exists?(latest_epp.id) } }

            it { is_expected.to have_http_status(201) }
          end

          context "and the presence policy is the same as latest EPP policy" do
            let(:presence_policy_id) { latest_epp.presence_policy }
            let(:error_code) do
              ["effective_at_join_table_with_given_date_and_resource_already_exists"]
            end

            it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
            it { expect { subject }.to_not change { EmployeePresencePolicy.exists?(latest_epp.id) } }

            it { is_expected.to have_http_status(422) }
            it do
              expect(subject.body)
                .to include "Join Table with given date and resource already exists"
            end

            it_behaves_like "Proper error response"
          end
        end

        context "and the effective at is before the latest EPP effective_at" do
          let(:effective_at) { latest_epp.effective_at - 2.days }

          context "and the presence policy is the same as the oldest EPP" do
            it { expect { subject }.to change { EmployeePresencePolicy.count }.by(1) }

            it { is_expected.to have_http_status(201) }
          end

          context "and the presence policy is different than the exisitng EPP's ones" do
            let(:presence_policy_id) { new_policy_id }

            it { expect { subject }.to change { EmployeePresencePolicy.count }.by(1) }

            it { is_expected.to have_http_status(201) }
          end
        end

        context "and the effective at is after than the latest EPP effective_at" do
          let(:effective_at) { latest_epp.effective_at + 1.week }

          context "and the presence policy is the same as the oldest EPP" do
            it { expect { subject }.to change { EmployeePresencePolicy.count }.by(1) }

            it { is_expected.to have_http_status(201) }
          end
        end
      end
    end

    context "with invalid params" do
      let(:new_account) { create(:account) }
      let(:category) { create(:time_off_category, account_id: employee.account_id) }
      let(:presence_policy) { create(:presence_policy, account_id: employee.account_id) }
      let(:time_off) do
        create(:time_off, :without_balance, employee: employee, time_off_category: category)
      end

      context "when there is employee balance after effective at" do
        let!(:balance) do
          create(:employee_balance,
            employee: employee, effective_at: 1.year.ago, time_off_category: category,
            time_off: time_off
          )
        end
        let(:error_code) { ["presence_policy_must_have_presence_days_assigned"] }

        it { expect { subject }.to_not change { employee.employee_presence_policies.count } }
        it { is_expected.to have_http_status(422) }

        it_behaves_like "Proper error response"
      end

      context "when employee does not belong to current account" do
        before { employee.update!(account: new_account) }

        it { expect { subject }.to_not change { employee.employee_presence_policies.count } }
        it { is_expected.to have_http_status(404) }
      end

      context "when the presence policy does not belong to current account" do
        before { presence_policy.update!(account: new_account) }

        it { expect { subject }.to_not change { employee.employee_presence_policies.count } }
        it { is_expected.to have_http_status(404) }
      end

      context "when current user is not account manager" do
        before { Account::User.current.update!(role: "user") }

        it { expect { subject }.to_not change { employee.employee_presence_policies.count } }
        it { is_expected.to have_http_status(403) }
      end

      context "when effective at is invalid format" do
        let(:effective_at) { "abc" }

        it { expect { subject }.to_not change { employee.employee_presence_policies.count } }
        it { is_expected.to have_http_status(422) }
      end
    end
  end

  context "PUT #update" do
    let(:id) { join_table_resource.id }
    let(:effective_at) { Date.new(2016, 1, 1) }
    let(:order_of_start_day) { join_table_resource.order_of_start_day }
    let!(:join_table_resource) do
      create(:employee_presence_policy,
        presence_policy: new_presence_policy, employee: employee, effective_at: 10.days.ago)
    end
    let(:new_presence_policy) { presence_policy }
    let(:params) { { id: id, effective_at: effective_at, order_of_start_day: order_of_start_day } }

    subject { put :update, params }

    context "when there are employee balances with time offs assigned" do
      let(:policy) { create(:time_off_policy) }
      let(:employee_policy) do
        create(:employee_time_off_policy, employee: employee, effective_at: 5.years.ago)
      end
      let!(:balances) do
        [2.months.ago, 2.months.since, 6.months.since].map do |date|
          create(:employee_balance_manual, :with_time_off,
            employee: employee, effective_at: date, time_off_category: policy.time_off_category)
        end
      end

      context "contract end next to join table" do
        context "and in previous contract period no join tables assigned" do
          before do
            join_table_resource.update!(effective_at: 1.week.since)
            contract_end
            rehired
          end

          context "after the update join table is one day after contract end" do
            let(:contract_end_date) { params[:effective_at] - 1.day }

            it { expect { subject }.to change { join_table_resource.reload.effective_at } }
            it { expect { subject }.to_not change { EmployeePresencePolicy.count } }

            it { is_expected.to have_http_status(200) }
          end

          context "befote the update join table was one day after contract end" do
            let(:effective_at) { 1.month.since }
            let(:contract_end_date) { join_table_resource.effective_at - 1.day }

            it { expect { subject }.to change { join_table_resource.reload.effective_at } }
            it { is_expected.to have_http_status(200) }
          end
        end

        context "and in previous contract period join tables assigned" do
          let!(:epp) do
            create(:employee_presence_policy,
              employee: employee, presence_policy: presence_policy, effective_at: 2.years.ago)
          end
          before do
            join_table_resource.update!(effective_at: 1.week.since)
            contract_end
            rehired
          end

          context "after the update join table is one day after contract end" do
            let(:contract_end_date) { params[:effective_at] - 1.day }

            it { expect { subject }.to change { EmployeePresencePolicy.with_reset.count }.by(-1) }
            it { expect { subject }.to change { EmployeePresencePolicy.count }.by(-1) }

            it { is_expected.to have_http_status(200) }

            context "and before and after it user had join tables with the same resource" do
              let(:new_policy) { create(:presence_policy, :with_presence_day, account: account) }
              let!(:new_epps) do
                [-2, 2].map do |day|
                  create(:employee_presence_policy,
                    employee: employee, presence_policy: new_policy,
                    effective_at: join_table_resource.effective_at + day.days)
                end
              end

              it { expect { subject }.to change { EmployeePresencePolicy.count }.by(-1) }
              it { expect { subject }.to change { EmployeePresencePolicy.with_reset.count }.by(-1) }
              it do
                expect { subject }.not_to change { EmployeePresencePolicy.exists?(new_epps.last.id) }
              end

              it { is_expected.to have_http_status(200) }
            end
          end

          context "before the update join table was one day after contract end" do
            let(:effective_at) { 1.month.since }
            let(:contract_end_date) { join_table_resource.effective_at - 1.day }

            it { expect { subject }.to change { EmployeePresencePolicy.count }.by(1) }
            it { expect { subject }.to change { EmployeePresencePolicy.with_reset.count }.by(1) }

            it { is_expected.to have_http_status(200) }

            context "and before and after new date are join tables with the same resource" do
              let!(:epp_between) do
                create(:employee_presence_policy,
                  employee: employee, effective_at: params[:effective_at] - 3.days)
              end
              let!(:new_epps) do
                [-2, 2].map do |day|
                  create(:employee_presence_policy,
                    employee: employee, presence_policy: new_presence_policy,
                    effective_at: params[:effective_at] + day.days)
                end
              end

              it { expect { subject }.to change { EmployeePresencePolicy.with_reset.count }.by(1) }
              it { expect { subject }.to change { EmployeePresencePolicy.not_reset.count }.by(0) }
              it do
                expect { subject }.not_to change { EmployeePresencePolicy.exists?(new_epps.last.id) }
              end
              it do
                expect { subject }
                  .not_to change { EmployeePresencePolicy.exists?(join_table_resource.id) }
              end

              it { is_expected.to have_http_status(200) }
            end
          end
        end
      end

      context "and join table was updated" do
        shared_examples "properly updates balances" do
          it { expect { subject }.to change { balances.second.reload.being_processed } }
          it { expect { subject }.to change { balances.last.reload.being_processed } }
          it { expect { subject }.to_not change { balances.first.reload.being_processed } }

          it { expect { subject }.to have_enqueued_job(UpdateBalanceJob).exactly(1) }
          it { is_expected.to have_http_status(200) }
        end

        shared_examples "does not updates balances" do
          it { expect { subject }.to_not change { balances.second.reload.being_processed } }
          it { expect { subject }.to_not change { balances.last.reload.being_processed } }
          it { expect { subject }.to_not change { balances.first.reload.being_processed } }

          it { expect { subject }.to_not have_enqueued_job(UpdateBalanceJob) }
          it { is_expected.to have_http_status(200) }
        end

        context "same date" do
          let(:effective_at) { join_table_resource.effective_at.to_date }

          context "and same order of start date" do
            it_behaves_like "does not updates balances"
            it { expect { subject }.to_not change { join_table_resource.reload.effective_at } }
            it { expect { subject }.to_not change { join_table_resource.reload.order_of_start_day } }
          end

          context "and different order of start date" do
            let!(:order_of_start_day) { join_table_resource.order_of_start_day + 1 }

            it_behaves_like "properly updates balances"
            it { expect { subject }.to_not change { join_table_resource.reload.effective_at } }
            it { expect { subject }.to change { join_table_resource.reload.order_of_start_day } }
          end
        end

        context "only order of start date" do
          let(:effective_at) { join_table_resource.effective_at.to_date }
          let(:order_of_start_day) { join_table_resource.order_of_start_day + 2 }

          it_behaves_like "properly updates balances"
          it { expect { subject }.to_not change { join_table_resource.reload.effective_at } }
          it { expect { subject }.to change { join_table_resource.reload.order_of_start_day } }
        end

        it_behaves_like "properly updates balances"

        context "and its previous date is before new one" do
          before { join_table_resource.update!(effective_at: 1.year.ago) }

          let(:effective_at) { 1.year.since }

          it { expect { subject }.to change { balances.second.reload.being_processed } }
          it { expect { subject }.to change { balances.last.reload.being_processed } }
          it { expect { subject }.to change { balances.first.reload.being_processed } }

          it { expect { subject }.to have_enqueued_job(UpdateBalanceJob).exactly(1) }
          it { is_expected.to have_http_status(200) }
        end
      end

      context "and join table was destroyed due to duplicated resource" do
        before do
          [4.months.ago, 4.month.since].map do |date|
            create(:employee_presence_policy,
              employee: employee, effective_at: date, presence_policy: presence_policy)
          end
        end

        it { expect { subject }.to change { balances.second.reload.being_processed } }
        it { expect { subject }.to change { balances.last.reload.being_processed } }
        it { expect { subject }.to_not change { balances.first.reload.being_processed } }

        it { expect { subject }.to have_enqueued_job(UpdateBalanceJob).exactly(1) }
        it { is_expected.to have_http_status(200) }
      end
    end

    context "with valid params" do
      it { expect { subject }.to change { join_table_resource.reload.effective_at } }

      it { is_expected.to have_http_status(200) }
      it "should have valid data in response body" do
        subject

        expect_json(effective_at: effective_at.to_date.to_s)
        expect_json_keys([:effective_at, :effective_till, :id, :assignation_id])
      end

      context "when at least 2 EPPs exist on the past" do
        let!(:first_epp) do
          create(:employee_presence_policy, employee: employee, presence_policy: presence_policy,
            effective_at: Date.today
          )
        end

        let!(:latest_epp) do
          create(:employee_presence_policy, employee: employee, effective_at: Date.today + 1.week)
        end

        context "and the effective at is equal to the lastest EPP effective_at" do
          let(:effective_at) { latest_epp.effective_at }

          context "and the presence policy is the same as the oldest EPP" do
            it { expect { subject }.to change { EmployeePresencePolicy.count }.by(-1) }
            it { expect { subject }.to change { EmployeePresencePolicy.exists?(latest_epp.id) } }
            it do
              expect { subject }
                .not_to change { EmployeePresencePolicy.exists?(join_table_resource.id) }
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

        context "and the effective at is before the lastest EPP effective_at" do
          let(:effective_at) { latest_epp.effective_at - 2.days }

          context "and the presence policy is the same as the oldest EPP" do
            it { expect { subject }.not_to change { EmployeePresencePolicy.count } }
            it do
              expect { subject }
                .not_to change { EmployeePresencePolicy.exists?(join_table_resource.id) }
            end
          end

          context "and the presence policy is different than the exisitng EPP's ones" do
            let(:new_presence_policy) do
              create(:presence_policy, :with_presence_day, account: account)
            end

            it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
          end
        end

        context "and the effective at is after than the lastest EPP effective_at" do
          let(:effective_at) { latest_epp.effective_at + 2.days }

          context "and the presence policy is the same as the oldest EPP" do
            it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
          end
        end
      end
    end


    context "with invalid params" do
      context "when there is employee balance" do
        before do
          create(:employee_balance, :with_time_off,
            employee: employee, effective_at: balance_effective_at)
        end

        context "after old effective_at" do
          let(:effective_at) { 5.years.ago }
          let(:balance_effective_at) { 2.days.ago }

          it { expect { subject }.to change { join_table_resource.reload.effective_at } }
          it { is_expected.to have_http_status(200) }

          it "returns valid response" do
            subject
            expect(response.body).to include join_table_resource.id
          end
        end

        context "after new effective_at" do
          let(:effective_at) { 5.years.ago }
          let(:balance_effective_at) { 5.days.ago }

          it { expect { subject }.to change { join_table_resource.reload.effective_at } }
          it { is_expected.to have_http_status(200) }

          it "returns valid response" do
            subject
            expect(response.body).to include join_table_resource.id
          end
        end
      end

      context "when resource is duplicated" do
        let!(:existing_resource) do
          join_table_resource.dup.tap { |resource| resource.update!(effective_at: "1/1/2016") }
        end
        let(:error_code) { ["effective_at_join_table_with_given_date_and_resource_already_exists"] }

        it { expect { subject }.to_not change { join_table_resource.reload.effective_at } }
        it { is_expected.to have_http_status(422) }

        it_behaves_like "Proper error response"
      end

      context "when user is not account manager" do
        before { Account::User.current.update!(role: "user", employee: employee) }

        it { expect { subject }.to_not change { join_table_resource.reload.effective_at } }
        it { is_expected.to have_http_status(403) }
      end

      context "when effective at is not valid" do
        let(:effective_at) { "abc" }

        it { expect { subject }.to_not change { join_table_resource.reload.effective_at } }
        it { is_expected.to have_http_status(422) }
      end

      context "when order_of_start_day is not valid" do
        context "when it's nil" do
          let(:order_of_start_day) { nil }

          it { expect { subject }.to_not change { join_table_resource.reload.effective_at } }
          it { is_expected.to have_http_status(422) }
        end

        context "when it's not int" do
          let(:order_of_start_day) { "abc" }

          it { expect { subject }.to_not change { join_table_resource.reload.effective_at } }
          it { is_expected.to have_http_status(422) }
        end

        context "when it's not in payload" do
          let(:params) { { id: id, effective_at: effective_at } }
          subject { put :update, params }

          it { expect { subject }.to_not change { join_table_resource.reload.effective_at } }
          it { is_expected.to have_http_status(422) }
        end
      end
    end
  end

  describe "DELETE #destroy" do
    let(:id) { employee_presence_policy.id }
    let!(:employee_presence_policy) do
      create(:employee_presence_policy,
        employee: employee, presence_policy: presence_policy, effective_at: Time.now)
    end
    subject { delete :destroy, { id: id } }

    context "with valid params" do
      context "when they are no join tables with the same resources before and after" do
        it { expect { subject }.to change { EmployeePresencePolicy.count }.by(-1) }

        it { is_expected.to have_http_status(204) }
      end

      context "when there is contract end in the future" do
        before do
          create(:employee_event,
            event_type: "contract_end", effective_at: 1.month.since, employee: employee)
        end

        it { expect { subject }.to change { EmployeePresencePolicy.count }.by(-2) }
        it { expect { subject }.to change { EmployeePresencePolicy.with_reset.count }.by(-1) }
        it { expect { subject }.to change { EmployeePresencePolicy.not_reset.count }.by(-1) }

        it { is_expected.to have_http_status(204) }

        context "when there is rehired" do
          let!(:hired_event) do
            create(:employee_event,
              event_type: "hired", effective_at: 2.months.since, employee: employee)
          end
          let!(:new_epp) do
            create(:employee_presence_policy,
              employee: employee, presence_policy: presence_policy, effective_at: 2.months.since)
          end
          let!(:employee_event) do
            create(:employee_event,
              event_type: "contract_end", effective_at: 3.months.since, employee: employee)
          end

          let(:id) { new_epp.id }

          it { expect { subject }.to change { EmployeePresencePolicy.count }.by(-2) }
          it { expect { subject }.to change { EmployeePresencePolicy.with_reset.count }.by(-1) }
          it { expect { subject }.to change { EmployeePresencePolicy.not_reset.count }.by(-1) }

          it { is_expected.to have_http_status(204) }
        end
      end

      context "when there is contract end day before join table" do
        let(:contract_end_date) { employee_presence_policy.effective_at - 1.day }

        context "and there is no join table after removed resource" do
          before do
            contract_end
            rehired
          end

          it { expect { subject }.to change { EmployeePresencePolicy.not_reset.count }.by(-1) }
          it { expect { subject }.to_not change { EmployeePresencePolicy.with_reset.count } }

          it { is_expected.to have_http_status(204) }
        end

        context "and there is join table after removed resource" do
          before do
            pp = create(:presence_policy, :with_presence_day, account: account)
            create(:employee_presence_policy,
              employee: employee, presence_policy: pp, effective_at: 1.year.ago)
            create(:employee_presence_policy,
              employee: employee, presence_policy: pp, effective_at: 1.year.since)
            contract_end
            rehired
          end

          it { expect { subject }.to change { EmployeePresencePolicy.not_reset.count }.by(-1) }
          it { expect { subject }.to change { EmployeePresencePolicy.with_reset.count }.by(1) }

          it { is_expected.to have_http_status(204) }
        end
      end

      context "when they are join tables with the same resources before and after" do
        let!(:same_resource_tables) do
          [Time.now - 1.week, Time.now + 1.week].map do |date|
            create(:employee_presence_policy,
              employee: employee, presence_policy: presence_policy, effective_at: date)
          end
        end

        it { expect { subject }.to change { EmployeePresencePolicy.count }.by(-1) }
        it { is_expected.to have_http_status(204) }
      end

      context "when there is employee balance but its effective at is before resource's" do
        let!(:time_off) do
          create(:time_off, start_time: 3.years.ago, end_time: 2.years.ago, employee: employee)
        end
        it { expect { subject }.to change { EmployeePresencePolicy.count }.by(-1) }
        it { expect { subject }.to_not change { time_off.employee_balance.reload.being_processed } }

        it { expect { subject }.to_not have_enqueued_job(UpdateBalanceJob) }
        it { is_expected.to have_http_status(204) }
      end

      context "when there is employee balance after" do
        let!(:time_off) do
          create(:time_off, start_time: 2.days.since, end_time: 4.days.since, employee: employee)
        end

        it { expect { subject }.to change { time_off.employee_balance.reload.being_processed } }
        it { expect { subject }.to have_enqueued_job(UpdateBalanceJob).exactly(1) }

        it { is_expected.to have_http_status(204) }
      end

      context "when there is contract_end" do
        let!(:contract_end) do
          create(:employee_event, employee: employee, effective_at: 3.months.from_now,
            event_type: "contract_end")
        end

        context "only one employee_presence_policy" do
          it { expect { subject }.to change(EmployeePresencePolicy, :count).by(-2) }
        end

        context "there are employee_presence_policies left" do
          let!(:employee_presence_policy_2) do
            create(:employee_presence_policy, employee: employee, effective_at: Time.zone.now)
          end

          it { expect { subject }.to change(EmployeePresencePolicy, :count).by(-1) }
        end
      end
    end

    context "with invalid params" do
      context "with invalid id" do
        let(:id) { "1ab" }

        it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
        it { is_expected.to have_http_status(404) }
      end

      context "when EmployeePresencePolicy belongs to other account" do
        before { employee_presence_policy.employee.update!(account: create(:account)) }

        it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
        it { is_expected.to have_http_status(404) }
      end

      context "when user is not an account manager" do
        before { Account::User.current.update!(role: "user", employee: employee) }

        it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
        it { is_expected.to have_http_status(403) }

        it "have valid error message" do
          subject

          expect(response.body).to include "You are not authorized to access this page."
        end
      end
    end
  end
end
