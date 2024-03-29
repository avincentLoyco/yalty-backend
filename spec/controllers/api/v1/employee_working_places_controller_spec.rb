require "rails_helper"

RSpec.describe API::V1::EmployeeWorkingPlacesController, type: :controller do
  include_context "shared_context_headers"
  include_context "shared_context_timecop_helper"

  let(:working_place) { create(:working_place, account: Account.current) }
  let(:new_employee) { create(:employee, account: Account.current) }
  let!(:employee) do
    create(:employee, account: Account.current, employee_working_places: [employee_working_place])
  end
  let!(:employee_working_place) do
    create(:employee_working_place,
      effective_at: 5.years.ago, working_place: working_place)
  end
  let(:contract_end) do
    create(:employee_event,
      event_type: "contract_end", employee: employee, effective_at: contract_end_date)
  end
  let(:rehired) do
    create(:employee_event,
      event_type: "hired", employee: employee, effective_at: contract_end_date + 1.day)
  end

  shared_examples "Proper error response" do
    before { subject }
    it { expect_json_keys("errors.*", %i(field messages status type codes employee_id)) }
    it "includes employee_id and error code" do
      expect_json("errors.0",
        employee_id: employee.id,
        codes: error_code)
    end
  end

  describe "reset join tables behaviour" do
    include_context "shared_context_join_tables_controller",
      join_table: :employee_working_place,
      resource: :working_place
  end

  describe "get #INDEX" do
    let!(:working_place_related) do
      create(:employee_working_place,
        working_place: employee_working_place.working_place, effective_at: 1.week.since,
        employee: new_employee
      )
    end
    let!(:employee_related) do
      create(:employee_working_place, employee: employee, effective_at: 1.week.since)
    end

    subject { get :index, params }

    context "when employee_id given" do
      let(:params) {{ employee_id: employee.id }}

      it { is_expected.to have_http_status(200) }

      it "has valid response body response body" do
        subject

        expect(response.body).to include(employee_working_place.id, employee_related.id)
        expect(response.body).to_not include(working_place_related.id)
      end
    end

    context "when working_place_id given" do
      let!(:new_ewp) do
        create(:employee_working_place,
          employee: employee, working_place: employee_working_place.working_place,
          effective_at: 1.week.ago
        )
      end
      let(:params) {{ working_place_id: employee_working_place.working_place.id }}

      it { is_expected.to have_http_status(200) }

      context "when no filter given" do
        before { subject }

        it { expect(response.body).to include(working_place_related.id, new_ewp.id) }
        it { expect(response.body).to_not include(employee_related.id, employee_working_place.id) }
      end

      context "when active filter given" do
        before do
          params.merge!({ filter: "active" })
          subject
        end

        it { expect(response.body).to include(working_place_related.id, new_ewp.id) }
        it { expect(response.body).to_not include(employee_related.id, employee_working_place.id) }
      end

      context "when inactive filter given" do
        before do
          params.merge!({ filter: "inactive" })
          subject
        end

        it { expect(response.body).to include(employee_working_place.id) }
        it do
          expect(response.body).to_not include(
            employee_related.id, working_place_related.id, new_ewp.id
          )
        end
      end
    end

    context "with invalid params" do
      context "when employee_id given" do
        let(:params) {{ employee_id: employee.id }}

        context "when employee does not belong to current account" do
          before { Account.current = create(:account) }

          it { is_expected.to have_http_status(404) }
        end

        context "when account user is not account manager" do
          before { Account::User.current.update!(role: "user" ) }

          it { is_expected.to have_http_status(403) }
        end
      end

      context "when working_place_id given" do
        let(:params) {{ working_place_id: employee_working_place.working_place.id }}

        context "when working_place does not belong to current account" do
          before { Account.current = create(:account) }

          it { is_expected.to have_http_status(404) }
        end

        context "when account user is not account manager" do
          before { Account::User.current.update!(role: "user" ) }

          it { is_expected.to have_http_status(403) }
        end
      end
    end
  end

  describe "post #CREATE" do
    subject { post :create, params }
    let(:new_working_place) { create(:working_place, account: Account.current) }
    let(:effective_at) { 1.month.since }
    let(:employee_id) { employee.id }
    let(:working_place_id) { new_working_place.id }
    let(:params) do
      {
        employee_id: employee_id,
        working_place_id: working_place_id,
        effective_at: effective_at,
      }
    end

    context "with valid params" do
      it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(1) }
      it { is_expected.to have_http_status(201) }

      context "response body" do
        before { subject }

        it "should contain proper keys" do
          expect_json_keys(
            :id, :type, :assignation_type, :id, :assignation_id, :effective_at, :effective_till
          )
        end
      end

      context "when there is contract end in the future" do
        context "and this is first employee contract end" do
          before do
            EmployeeWorkingPlace.delete_all
            create(:employee_event,
              employee: employee, event_type: "contract_end", effective_at: 1.week.since)
          end
          let(:effective_at) { Time.zone.today }

          it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(2) }
          it { expect { subject }.to change { EmployeeWorkingPlace.with_reset.count }.by(1) }
          it { expect { subject }.to change { EmployeeWorkingPlace.not_reset.count }.by(1) }

          it { is_expected.to have_http_status(201) }
        end

        context "and employee is rehired" do
          before do
            create(:employee_working_place,
              employee: employee, working_place: working_place, effective_at: 1.week.ago)
            create(:employee_event,
              event_type: "contract_end", effective_at: 1.week.since, employee: employee)
            create(:employee_event,
              event_type: "hired", employee: employee, effective_at: 1.month.since)
            create(:employee_event,
              event_type: "contract_end", effective_at: 2.months.since, employee: employee)
          end

          let(:effective_at) { 1.month.since }

          it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(2) }
          it { expect { subject }.to change { EmployeeWorkingPlace.with_reset.count }.by(1) }
          it { expect { subject }.to change { EmployeeWorkingPlace.not_reset.count }.by(1) }

          it { is_expected.to have_http_status(201) }
        end
      end

      context "when there are employee balances after employee working place effective_at" do
        let(:holiday_policy) { create(:holiday_policy, account: account) }
        let(:categories) { create_list(:time_off_category, 2, account: account) }
        let(:policies) { categories.map { |cat| create(:time_off_policy, time_off_category: cat) } }
        let!(:employee_policies) do
          policies.map do |policy|
            create(:employee_time_off_policy,
              employee: employee, time_off_policy: policy, effective_at: employee.hired_date)
          end
        end
        let!(:time_offs) do
          dates_with_categories =
            [[Time.now + 3.months, Time.now + 4.months, categories.first],
            [Time.now + 5.months, Time.now + 6.months, categories.last]]
          dates_with_categories.map do |starts, ends, category|
            create(:time_off,
              end_time: ends, start_time: ends, employee: employee, time_off_category: category)
          end
        end
        let!(:balances) do
          TimeOff.all.map {|time_off| TimeOffs::Approve.call(time_off) }
          TimeOff.all.map(&:employee_balance).sort_by { |b| b[:effective_at] }
        end

        context "when there is contract end date" do
          before do
            contract_end
            rehired
          end

          let(:contract_end_date) { Time.now }
          let(:working_place_id) { working_place.id }
          let(:effective_at) { 1.day.since }

          it { expect { subject }.to change { EmployeeWorkingPlace.not_reset.count }.by(1) }
          it { expect { subject }.to change { EmployeeWorkingPlace.with_reset.count }.by(-1) }
          it { is_expected.to have_http_status(201) }

          context "when there is ewp with the same working place after" do
            let!(:new_working_place) do
              create(:employee_working_place,
                employee: employee, working_place: working_place, effective_at: 1.month.since)
            end

            it { expect { subject }.to change { EmployeeWorkingPlace.with_reset.count }.by(-1) }
            it do
              expect { subject }.to change { EmployeeWorkingPlace.exists?(new_working_place.id) }
            end
            it { is_expected.to have_http_status(201) }
          end
        end

        context "when new EmployeeWorkingPlace is created" do
          context "and previous policy has the same holiday policy assigned" do
            before do
              working_place.update!(holiday_policy: holiday_policy)
              new_working_place.update!(holiday_policy: holiday_policy)
            end

            it { expect { subject }.to_not change { balances.first.reload.being_processed } }
            it { expect { subject }.to_not change { balances.last.reload.being_processed } }
            it { expect { subject }.to_not have_enqueued_job(UpdateBalanceJob) }

            it { is_expected.to have_http_status(201) }
          end

          context "when new employee working place is reassigned" do
            before { new_working_place.update!(holiday_policy: holiday_policy) }
            let(:effective_at) { EmployeeWorkingPlace.first.effective_at }

            it { expect { subject }.to change { balances.first.reload.being_processed }.to true }
            it { expect { subject }.to change { balances.last.reload.being_processed }.to true }
            it { expect { subject }.to have_enqueued_job(UpdateBalanceJob).exactly(2) }

            it { is_expected.to have_http_status(201) }
          end

          context "when employee does not have previous employee working place" do
            before { EmployeeWorkingPlace.destroy_all }

            context "and new working place does not have holiday policy assigned" do
              it { expect { subject }.to_not have_enqueued_job(UpdateBalanceJob) }

              it { is_expected.to have_http_status(201) }
            end

            context "and new working place has holiday policy assigned" do
              before { new_working_place.update!(holiday_policy: holiday_policy) }

              it { expect { subject }.to change { balances.first.reload.being_processed }.to true }
              it { expect { subject }.to change { balances.last.reload.being_processed }.to true }
              it { expect { subject }.to have_enqueued_job(UpdateBalanceJob).exactly(2) }

              it { is_expected.to have_http_status(201) }
            end
          end
        end
      end

      context "when at least 2 EWPs exist on the past" do
        let(:new_working_place_id) { create(:working_place, account: account).id }
        let!(:first_ewp) do
          create(:employee_working_place, employee: employee, working_place: new_working_place,
            effective_at: Date.today
          )
        end
        let!(:latest_ewp) do
          create(:employee_working_place, employee: employee, effective_at: Date.today + 1.week)
        end

        context "and the effective at is equal to the lastest EWP effective_at" do
          let(:effective_at) { latest_ewp.effective_at }

          context "and the working place is the same as the oldest EWP" do
            it { expect { subject }.to change { EmployeeWorkingPlace.exists?(latest_ewp.id) } }
            it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(-1) }

            it { is_expected.to have_http_status(205) }
          end

          context "and the working place is different than the exisitng EWP's ones" do
            let(:working_place_id) { new_working_place_id }

            it { expect { subject }.to change { EmployeeWorkingPlace.exists?(latest_ewp.id) } }
            it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }

            it { is_expected.to have_http_status(201) }
          end

          context "and the working place is the same as latest EWP policy" do
            let(:working_place_id) { latest_ewp.working_place }
	    let(:error_code) do
	      ["effective_at_join_table_with_given_date_and_resource_already_exists"]
	    end

            it { expect { subject }.to_not change { EmployeeWorkingPlace.exists?(latest_ewp.id) } }
            it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }

            it { is_expected.to have_http_status(422) }
            it_behaves_like "Proper error response"

            it do
              expect(subject.body)
                .to include "Join Table with given date and resource already exists"
            end
          end
        end

        context "and the effective at is before the lastest EWP effective_at" do
          let(:effective_at) { latest_ewp.effective_at - 2.days }

          context "and the working place is the same as the latest EWP" do
            it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }

            it { is_expected.to have_http_status(205) }
          end

          context "and the working place is different than the exisitng EWP's ones" do
            let(:working_place_id) { new_working_place_id }

            it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(1) }
            it { is_expected.to have_http_status(201) }
          end
        end

        context "and the effective at is after than the latest EWP effective_at" do
          let(:effective_at) { latest_ewp.effective_at + 1.week }

          context "and the working place is the same as the oldest EWP" do
            it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(1) }

            it { is_expected.to have_http_status(201) }
          end
        end
      end
    end

    context "with invalid params" do
      context "when invalid employee id (or employee belongs to other account)" do
        let(:employee_id) { "abc" }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { is_expected.to have_http_status(404) }
      end

      context "when invalid working place id" do
        let(:working_place_id) { "abc" }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { is_expected.to have_http_status(404) }
      end

      context "when effective at is invalid format" do
        let(:effective_at) { "**" }

        it { expect { subject }.to_not change { employee.employee_presence_policies.count } }
        it { is_expected.to have_http_status(422) }
      end

      context "when working place with given id belongs to other account" do
        let(:new_working_place) { create(:working_place) }
        let(:working_place_id) { new_working_place.id }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { is_expected.to have_http_status(404) }
      end

      context "when account user is not account manager" do
        before { Account::User.current.update!(role: "user" ) }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { is_expected.to have_http_status(403) }
      end

      context "when effective already taken and the same resource send" do
        let(:effective_at) { employee_working_place.effective_at }
        let(:working_place_id) { employee_working_place.working_place_id }
        let(:error_code) { ["effective_at_join_table_with_given_date_and_resource_already_exists"] }

        it { is_expected.to have_http_status(422) }
        it_behaves_like "Proper error response"
      end

      context "when effective at before first working place effective at" do
        let(:effective_at) { employee_working_place.effective_at - 1.month }
        let(:error_code) { ["effective_at_cant_be_set_outside_of_employee_contract_period"] }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { is_expected.to have_http_status(422) }
        it_behaves_like "Proper error response"
      end
    end
  end

  describe "put #UPDATE" do
    subject { put :update, { effective_at: effective_at, id: id } }
    let(:effective_at) { 1.day.ago }
    let(:id) { new_employee_working_place.id }
    let!(:new_employee_working_place) do
      create(:employee_working_place,
        employee: employee, effective_at: 2.days.ago)
    end

    context "with valid params" do
      context "when there are no employee_working_places with the same resource" do
        it { expect { subject }.to change { new_employee_working_place.reload.effective_at } }

        it { is_expected.to have_http_status(200) }
        it "should have valid data in response body" do
          subject

          expect_json(effective_at: effective_at.to_date.to_s)
          expect_json_keys([:effective_at, :effective_till, :id, :assignation_id])
        end
      end

      context "when they are balances with time offs after effective_at" do
        let!(:newest_employee_working_place) do
          employee_working_place.dup.tap { |ewp| ewp.update!(effective_at: 6.months.since) }
        end
        let(:holiday_policy) { create(:holiday_policy, account: account) }
        let(:categories) { create_list(:time_off_category, 2, account: account) }
        let(:policies) { categories.map { |cat| create(:time_off_policy, time_off_category: cat) } }
        let!(:employee_policies) do
          policies.map do |policy|
            create(:employee_time_off_policy,
              employee: employee, time_off_policy: policy, effective_at: employee.hired_date)
          end
        end
        let!(:time_offs) do
          dates_with_categories =
            [[1.year.ago, 11.months.ago, categories.first],
             [3.months.since, 4.months.since, categories.first],
             [5.months.since, 6.months.since, categories.last]]
          dates_with_categories.map do |starts, ends, category|
            create(:time_off,
              end_time: ends, start_time: ends, employee: employee, time_off_category: category)
          end
        end
        let!(:balances) do
          TimeOff.all.map {|time_off| TimeOffs::Approve.call(time_off) }
          TimeOff.all.map(&:employee_balance).sort_by { |b| b[:effective_at] }
        end
        before do
          new_employee_working_place.working_place.update!(holiday_policy: holiday_policy)
        end

        context "when there is contract end" do
          let!(:ewp_a) do
            create(:employee_working_place,
              employee: employee, effective_at: 14.months.since,
              working_place: newest_employee_working_place.working_place)
          end
          let!(:ewps_b) do
            [8.months.since, 2.years.since].map do |date|
              create(:employee_working_place,
                employee: employee, effective_at: date,
                working_place: new_employee_working_place.working_place)
            end
          end

          context "and previous effective at was one day after" do
            let(:contract_end_date) { "29/12/2015".to_date }
            let(:effective_at) { 14.months.since }
            before do
              contract_end
              rehired
            end

            it { expect { subject }.to change { EmployeeWorkingPlace.not_reset.count }.by(-3) }
            it { expect { subject }.to change { EmployeeWorkingPlace.with_reset.count }.by(1) }
            it { expect { subject }.to change { EmployeeWorkingPlace.exists?(ewps_b.last.id) } }
            it { expect { subject }.to change { EmployeeWorkingPlace.exists?(ewp_a.id) } }
            it do
              expect { subject }
                .to change { EmployeeWorkingPlace.exists?(new_employee_working_place.id) }
            end

            it { is_expected.to have_http_status(205) }
          end

          context "and new effective_at is one day after" do
            let(:contract_end_date) { "28/12/2015".to_date }
            let(:id) { ewp_a.id }
            let(:effective_at) { "29/12/2015"}

            before do
              contract_end
              rehired
            end

            it { expect { subject }.to change { EmployeeWorkingPlace.with_reset.count }.by(-1) }
            it { expect { subject }.to change { EmployeeWorkingPlace.not_reset.count }.by(-1) }
            it { expect { subject }.to change { EmployeeWorkingPlace.exists?(ewps_b.last.id) } }
            it { expect { subject }.to change { ewp_a.reload.effective_at } }

            it { is_expected.to have_http_status(200) }
          end
        end

        context "when join table was updated" do
          let(:effective_at) { 2.years.since }

          it { expect { subject }.to change { balances.last.reload.being_processed } }
          it { expect { subject }.to change { balances.second.reload.being_processed } }

          it { expect { subject }.to_not change { balances.first.reload.being_processed } }

          it { expect { subject }.to have_enqueued_job(UpdateBalanceJob).exactly(2) }
        end

        context "when join table was destroyed" do
          let(:id) { newest_employee_working_place.id }

          context "and there was an assignation join table" do
            let(:effective_at) { 2.days.ago }

            it { expect { subject }.to_not change { balances.first.reload.being_processed } }

            it { expect { subject }.to change { balances.second.reload.being_processed } }
            it { expect { subject }.to change { balances.last.reload.being_processed } }
            it { expect { subject }.to have_enqueued_job(UpdateBalanceJob).exactly(2) }
          end

          context "and there was not an assignation join table" do
            let(:effective_at) { 1.year.ago }

            it { expect { subject }.to_not change { balances.first.reload.being_processed } }
            it { expect { subject }.to_not change { balances.second.reload.being_processed } }

            it { expect { subject }.to change { balances.last.reload.being_processed } }

            it { expect { subject }.to have_enqueued_job(UpdateBalanceJob).exactly(1) }
          end
        end
      end

      context "when at least 2 EWPs exist on the past" do
        let!(:first_ewp) do
          create(:employee_working_place, employee: employee, effective_at: Date.today,
            working_place: new_employee_working_place.working_place
          )
        end
        let!(:latest_ewp) do
          create(:employee_working_place, employee: employee, effective_at: Date.today + 1.week)
        end

        context "and the effective at is equal to the lastest EWP effective_at" do
          let(:effective_at) { latest_ewp.effective_at }

          context "and the working place is the same as the oldest EWP" do
            it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(-2) }
            it { expect { subject }.to change { EmployeeWorkingPlace.exists?(latest_ewp.id) } }
            it do
              expect { subject }
                .to change { EmployeeWorkingPlace.exists?(new_employee_working_place.id) }
            end

            it { is_expected.to have_http_status(205) }
          end

          context "and the working place is different than the exisitng EWP's ones" do
            before { new_employee_working_place.update!(working_place: new_working_place) }
            let(:new_working_place) { create(:working_place, account: account) }

            it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(-1) }
            it { expect { subject }.to change { EmployeeWorkingPlace.exists?(latest_ewp.id) } }

            it { is_expected.to have_http_status(200) }
          end
        end

        context "and the effective at is before the lastest EWP effective_at" do
          let(:effective_at) { latest_ewp.effective_at - 2.days }

          context "and the working place is the same as the oldest EWP" do
            it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(-1) }
            it do
              expect { subject }
                .to change { EmployeeWorkingPlace.exists?(new_employee_working_place.id) }
            end

            it { is_expected.to have_http_status(205) }
          end

          context "and the working place is different than the exisitng EWP's ones" do
            before { new_employee_working_place.update!(working_place: new_working_place) }
            let(:new_working_place) { create(:working_place, account: account) }

            it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
            it { is_expected.to have_http_status(200) }
          end
        end

        context "and the effective at is after than the lastest EWP effective_at" do
          let(:effective_at) { latest_ewp.effective_at + 2.days }

          context "and the working place is the same as the oldest EWP" do
            it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }

            it { is_expected.to have_http_status(200) }
          end
        end
      end
    end

    context "with invalid params" do
      context "when account user is not an account manager" do
        before { Account::User.current.update!(role: "user" ) }

        it { expect { subject }.to_not change { employee_working_place.reload.effective_at } }
        it { is_expected.to have_http_status(403) }
      end

      context "when effective at is invalid format" do
        let(:effective_at) { "987" }

        it { expect { subject }.to_not change { employee.employee_presence_policies.count } }
        it { is_expected.to have_http_status(422) }
      end

      context "when existing join table has the same resource assigned" do
        let!(:new_ewp) do
          employee_working_place.dup.tap { |ewp| ewp.update!(effective_at: Time.now) }
        end
        let(:id) { new_ewp }
        let(:effective_at) { employee_working_place.effective_at }
        let(:error_code) { ["effective_at_join_table_with_given_date_and_resource_already_exists"] }

        it { expect { subject }.to_not change { employee_working_place.reload.effective_at } }
        it do
          expect(subject.body).to include "Join Table with given date and resource already exists"
        end

        it { is_expected.to have_http_status(422) }
        it_behaves_like "Proper error response"
      end

      context "when there is employee balance" do
        before do
          create(:time_off,
            employee: employee, end_time: balance_effective_at,
            start_time: balance_effective_at - 2.days)
        end

        context "after old effective_at" do
          let(:effective_at) { 5.years.since }
          let(:balance_effective_at) { 2.days.since }

          it { expect { subject }.to change { new_employee_working_place.reload.effective_at } }
          it { is_expected.to have_http_status(200) }

          it "returns valid response" do
            subject

            expect(response.body).to include new_employee_working_place.id
          end
        end

        context "after new effective_at" do
          let(:effective_at) { 4.years.ago }
          let(:balance_effective_at) { 4.days.ago }

          it { expect { subject }.to change { new_employee_working_place.reload.effective_at } }
          it { is_expected.to have_http_status(200) }

          it "returns valid response" do
            subject

            expect(response.body).to include new_employee_working_place.id
          end

          context "and new join table date is in the existing join table date" do
            before do
              employee_working_place.update!(
                working_place: new_employee_working_place.working_place)
            end
            let(:effective_at) { 5.years.ago }
            let(:error_code) do
              ["effective_at_join_table_with_given_date_and_resource_already_exists"]
            end

            it { expect { subject }.to_not change { new_employee_working_place.reload.effective_at } }
            it { is_expected.to have_http_status(422) }
            it_behaves_like "Proper error response"
          end
        end
      end
    end
  end

  describe "DELETE #destroy" do
    let(:id) { join_table.id }
    let!(:join_table) do
      create(:employee_working_place,
        employee: employee, working_place: create(:working_place, account: account),
        effective_at: Time.now)
    end
    subject { delete :destroy, { id: id } }

    context "with valid params" do
      context "when they are no join tables with the same resources before and after" do
        it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(-1) }

        it { is_expected.to have_http_status(204) }
      end

      context "when they are join tables with the same resources before and after" do
        let!(:same_resource_tables) do
          [Time.now - 1.week, Time.now + 1.week].map do |date|
            create(:employee_working_place,
              employee: employee, working_place: working_place, effective_at: date)
          end
        end

        it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(-2) }

        it { is_expected.to have_http_status(204) }
      end

      context "when there is employee balance but its effective at is before resource's" do
        let(:employee_balance) do
          create(:employee_balance, :with_time_off, employee: employee,
            effective_at: join_table.effective_at - 5.days)
        end

        it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(-1) }

        it { is_expected.to have_http_status(204) }
      end

      context "when there is contract end in the future" do
        before do
          EmployeeWorkingPlace.where.not(id: join_table.id).delete_all
          create(:employee_event,
            event_type: "contract_end", effective_at: 1.month.since, employee: employee)
        end

        it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(-2) }
        it { expect { subject }.to change { EmployeeWorkingPlace.with_reset.count }.by(-1) }
        it { expect { subject }.to change { EmployeeWorkingPlace.not_reset.count }.by(-1) }

        it { is_expected.to have_http_status(204) }

        context "when there is rehired" do
          let!(:hired_event) do
            create(:employee_event,
              event_type: "hired", effective_at: 2.months.since, employee: employee)
          end
          let!(:new_epp) do
            create(:employee_working_place,
              employee: employee, working_place: working_place, effective_at: 2.months.since)
          end
          let!(:employee_event) do
            create(:employee_event,
              event_type: "contract_end", effective_at: 3.months.since, employee: employee)
          end

          let(:id) { new_epp.id }

          it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(-2) }
          it { expect { subject }.to change { EmployeeWorkingPlace.with_reset.count }.by(-1) }
          it { expect { subject }.to change { EmployeeWorkingPlace.not_reset.count }.by(-1) }

          it { is_expected.to have_http_status(204) }
        end
      end


      context "when there are employee balances after resource effective at" do
        let!(:vacation_toc) do
          create(:time_off_category, account: employee.account, name: "vacation")
        end
        let(:holiday_policy) { create(:holiday_policy, account: account) }
        let(:categories) { create_list(:time_off_category, 2, account: account) + [vacation_toc] }
        let(:policies) { categories.map { |cat| create(:time_off_policy, time_off_category: cat) } }
        let!(:employee_policies) do
          policies.map do |policy|
            create(:employee_time_off_policy,
              employee: employee, time_off_policy: policy, effective_at: employee.hired_date)
          end
        end
        let!(:time_offs) do
          dates_with_categories =
            [[Time.now + 3.months, Time.now + 4.months, categories.first],
            [Time.now + 5.months, Time.now + 6.months, categories.last]]
          dates_with_categories.map do |starts, ends, category|
            create(:time_off,
              end_time: ends, start_time: ends, employee: employee, time_off_category: category)
          end
        end
        let!(:balances) do
          TimeOff.all.map {|time_off| TimeOffs::Approve.call(time_off) }
          TimeOff.all.map(&:employee_balance)
        end

        context "when employee working place effective at is one day after contract end" do
          let(:contract_end_date) { Time.now }
          let!(:new_working_place) do
            create(:employee_working_place,
              employee: employee, effective_at: 1.week.since, working_place: working_place)
          end

          before do
            join_table.update!(effective_at: Time.now + 1.day)
            contract_end
            rehired
          end

          it { expect { subject }.to change { EmployeeWorkingPlace.exists?(join_table.id) } }
          it { expect { subject }.to change { EmployeeWorkingPlace.not_reset.count }.by(-1) }
          it { expect { subject }.to change { EmployeeWorkingPlace.with_reset.count }.by(1) }
          it do
            expect { subject }.to_not change { EmployeeWorkingPlace.exists?(new_working_place.id) }
          end

          it { is_expected.to have_http_status(204) }
        end

        context "when previous employee working places has the same holiday policy" do
          before { WorkingPlace.not_reset.update_all(holiday_policy_id: holiday_policy.id) }

          it { expect { subject }.to_not change { balances.first.reload.being_processed } }
          it { expect { subject }.to_not change { balances.last.reload.being_processed } }
          it { expect { subject }.to_not have_enqueued_job(UpdateBalanceJob) }

          it { is_expected.to have_http_status(204) }
        end

        context "when previous employee working place has different holiday policy" do
          before { WorkingPlace.not_reset.last.update!(holiday_policy_id: holiday_policy.id) }

          context "and there are no employee balances with time offs assigned" do
            before { Employee::Balance.destroy_all }

            it { expect { subject }.to_not have_enqueued_job(UpdateBalanceJob) }

            it { is_expected.to have_http_status(204) }
          end

          context "and there are employee balances with time offs assigned" do
            it { expect { subject }.to change { balances.first.reload.being_processed }.to true }
            it { expect { subject }.to change { balances.last.reload.being_processed }.to true }
            it { expect { subject }.to have_enqueued_job(UpdateBalanceJob).exactly(2) }

            it { is_expected.to have_http_status(204) }
          end
        end
      end
    end

    context "with invalid params" do
      context "with invalid id" do
        let(:id) { "1ab" }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { is_expected.to have_http_status(404) }
      end

      context "when EmployeeWorkingPlace belongs to other account" do
        before { employee_working_place.employee.update!(account: create(:account)) }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { is_expected.to have_http_status(404) }
      end

      context "when user is not an account manager" do
        before { Account::User.current.update!(role: "user", employee: employee) }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { is_expected.to have_http_status(403) }

        it "have valid error message" do
          subject

          expect(response.body).to include "You are not authorized to access this page."
        end
      end
    end

    context "when there is contract_end" do
      let!(:contract_end) do
        create(:employee_event, employee: employee, effective_at: 3.months.from_now,
          event_type: "contract_end")
      end

      context "only one employee_working_place" do
        before { employee.reload.employee_working_places.order(:effective_at).first.destroy }

        it { expect { subject }.to change(EmployeeWorkingPlace, :count).by(-2) }
      end

      context "there are employee_working_places left" do
        let!(:employee_working_place_2) do
          create(:employee_working_place, employee: employee, effective_at: Time.zone.now)
        end

        it { expect { subject }.to change(EmployeeWorkingPlace, :count).by(-1) }
      end
    end
  end
end
