require 'rails_helper'

RSpec.describe API::V1::EmployeeWorkingPlacesController, type: :controller do
  include_context 'shared_context_headers'
  include_context 'shared_context_timecop_helper'

  let(:working_place) { create(:working_place, account: Account.current) }
  let(:new_employee) { create(:employee, account: Account.current) }
  let!(:employee) do
    create(:employee, account: Account.current, employee_working_places: [employee_working_place])
  end
  let!(:employee_working_place) do
    create(:employee_working_place, effective_at: 5.years.ago, working_place: working_place)
  end

  describe 'get #INDEX' do
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

    context 'when employee_id given' do
      let(:params) {{ employee_id: employee.id }}

      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it { expect(response.body).to include(employee_working_place.id, employee_related.id) }
        it { expect(response.body).to_not include(working_place_related.id) }
      end
    end

    context 'when working_place_id given' do
      let(:params) {{ working_place_id: employee_working_place.working_place.id }}

      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it { expect(response.body).to include(working_place_related.id, employee_working_place.id) }
        it { expect(response.body).to_not include(employee_related.id) }
      end
    end

    context 'with invalid params' do
      context 'when employee_id given' do
        let(:params) {{ employee_id: employee.id }}

        context 'when employee does not belong to current account' do
          before { Account.current = create(:account) }

          it { is_expected.to have_http_status(404) }
        end

        context 'when account user is not account manager' do
          before { Account::User.current.update!(account_manager: false ) }

          it { is_expected.to have_http_status(403) }
        end
      end

      context 'when working_place_id given' do
        let(:params) {{ working_place_id: employee_working_place.working_place.id }}

        context 'when working_place does not belong to current account' do
          before { Account.current = create(:account) }

          it { is_expected.to have_http_status(404) }
        end

        context 'when account user is not account manager' do
          before { Account::User.current.update!(account_manager: false ) }

          it { is_expected.to have_http_status(403) }
        end
      end
    end
  end

  describe 'post #CREATE' do
    subject { post :create, params }
    let(:new_working_place) { create(:working_place, account: Account.current) }
    let(:effective_at) { 1.month.since }
    let(:employee_id) { employee.id }
    let(:working_place_id) { new_working_place.id }
    let(:params) do
      {
        id: employee_id,
        working_place_id: working_place_id,
        effective_at: effective_at
      }
    end

    context 'with valid params' do
      it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(1) }
      it { is_expected.to have_http_status(201) }

      context 'response body' do
        before { subject }

        it 'should contain proper keys' do
          expect_json_keys(
            :id, :type, :assignation_type, :id, :assignation_id, :effective_at, :effective_till
          )
        end
      end

      context 'when at least 2 EWPs exist on the past' do
        let(:new_working_place_id) { create(:working_place, account: account).id }
        let!(:first_ewp) do
          create(:employee_working_place, employee: employee, working_place: new_working_place,
            effective_at: Date.today
          )
        end
        let!(:latest_ewp) do
          create(:employee_working_place, employee: employee, effective_at: Date.today + 1.week)
        end

        context 'and the effective at is equal to the lastest EWP effective_at' do
          let(:effective_at) { latest_ewp.effective_at }

          context 'and the working place is the same as the oldest EWP' do
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

          context 'and the working place is the same as latest EWP policy' do
            let(:working_place_id) { latest_ewp.working_place }

            it { expect { subject }.to_not change { EmployeeWorkingPlace.exists?(latest_ewp.id) } }
            it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }

            it { is_expected.to have_http_status(422) }
            it do
              expect(subject.body)
                .to include 'Join Table with given date and resource already exists'
            end
          end
        end

        context 'and the effective at is before the lastest EWP effective_at' do
          let(:effective_at) { latest_ewp.effective_at - 2.days }

          context 'and the working place is the same as the latest EWP' do
            it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }

            it { is_expected.to have_http_status(205) }
          end

          context "and the working place is different than the exisitng EWP's ones" do
            let(:working_place_id) { new_working_place_id }

            it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(1) }
            it { is_expected.to have_http_status(201) }
          end
        end

        context 'and the effective at is after than the latest EWP effective_at' do
          let(:effective_at) { latest_ewp.effective_at + 1.week }

          context 'and the working place is the same as the oldest EWP' do
            it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(1) }

            it { is_expected.to have_http_status(201) }
          end
        end
      end
    end

    context 'with invalid params' do
      context 'when invalid employee id (or employee belongs to other account)' do
        let(:employee_id) { 'abc' }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when invalid working place id' do
        let(:working_place_id) { 'abc' }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when effective at is invalid format' do
        let(:effective_at) { '**' }

        it { expect { subject }.to_not change { employee.employee_presence_policies.count } }
        it { is_expected.to have_http_status(422) }
      end

      context 'when working place with given id belongs to other account' do
        let(:new_working_place) { create(:working_place) }
        let(:working_place_id) { new_working_place.id }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when account user is not account manager' do
        before { Account::User.current.update!(account_manager: false ) }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { is_expected.to have_http_status(403) }
      end

      context 'when effective already taken and the same resource send' do
        let(:effective_at) { employee_working_place.effective_at }
        let(:working_place_id) { employee_working_place.working_place_id }

        it { is_expected.to have_http_status(422) }
      end

      context 'when effective at before first working place effective at' do
        let(:effective_at) { employee_working_place.effective_at - 1.month }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { is_expected.to have_http_status(422) }
      end
    end
  end

  describe 'put #UPDATE' do
    subject { put :update, { effective_at: effective_at, id: id } }
    let(:effective_at) { 1.day.ago }
    let(:id) { new_employee_working_place.id }
    let!(:new_employee_working_place) do
      create(:employee_working_place,
        employee: employee, effective_at: 2.days.ago)
    end

    context 'with valid params' do
      context 'when there are no employee_working_places with the same resource' do
        it { expect { subject }.to change { new_employee_working_place.reload.effective_at } }

        it { is_expected.to have_http_status(200) }
        it 'should have valid data in response body' do
          subject

          expect_json(effective_at: effective_at.to_date.to_s)
          expect_json_keys([:effective_at, :effective_till, :id, :assignation_id])
        end
      end

      context 'when at least 2 EWPs exist on the past' do
        let!(:first_ewp) do
          create(:employee_working_place, employee: employee, effective_at: Date.today,
            working_place: new_employee_working_place.working_place
          )
        end
        let!(:latest_ewp) do
          create(:employee_working_place, employee: employee, effective_at: Date.today + 1.week)
        end

        context 'and the effective at is equal to the lastest EWP effective_at' do
          let(:effective_at) { latest_ewp.effective_at }

          context 'and the working place is the same as the oldest EWP' do
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

        context 'and the effective at is before the lastest EWP effective_at' do
          let(:effective_at) { latest_ewp.effective_at - 2.days }

          context 'and the working place is the same as the oldest EWP' do
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

        context 'and the effective at is after than the lastest EWP effective_at' do
          let(:effective_at) { latest_ewp.effective_at + 2.days }

          context 'and the working place is the same as the oldest EWP' do
            it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }

            it { is_expected.to have_http_status(200) }
          end
        end
      end
    end

    context 'with invalid params' do
      context 'when account user is not an account manager' do
        before { Account::User.current.update!(account_manager: false ) }

        it { expect { subject }.to_not change { employee_working_place.reload.effective_at } }
        it { is_expected.to have_http_status(403) }
      end

      context 'when effective at is invalid format' do
        let(:effective_at) { '987' }

        it { expect { subject }.to_not change { employee.employee_presence_policies.count } }
        it { is_expected.to have_http_status(422) }
      end

      context 'when existing join table has the same resource assigned' do
        let!(:new_ewp) do
          employee_working_place.dup.tap { |ewp| ewp.update!(effective_at: Time.now) }
        end
        let(:id) { new_ewp }
        let(:effective_at) { employee_working_place.effective_at }

        it { expect { subject }.to_not change { employee_working_place.reload.effective_at } }
        it do
          expect(subject.body).to include 'Join Table with given date and resource already exists'
        end

        it { is_expected.to have_http_status(422) }
      end

      context 'when there is employee balance' do
        before do
          create(:time_off,
            employee: employee, end_time: balance_effective_at,
            start_time: balance_effective_at - 2.days)
        end

        context 'after old effective_at' do
          let(:effective_at) { 5.years.since }
          let(:balance_effective_at) { 2.days.since }

          it { expect { subject }.to_not change { new_employee_working_place.reload.effective_at } }
          it { is_expected.to have_http_status(422) }

          it 'has valid error in response body' do
            subject

            expect(response.body).to include 'Employee balance after effective at already exists'
          end
        end

        context 'after new effective_at' do
          let(:effective_at) { 4.years.ago }
          let(:balance_effective_at) { 4.days.ago }

          it { expect { subject }.to_not change { new_employee_working_place.reload.effective_at } }
          it { is_expected.to have_http_status(422) }

          it 'has valid error in response body' do
            subject

            expect(response.body).to include 'Employee balance after effective at already exists'
          end

          context 'and new join table date is in the existing join table date' do
            let(:effective_at) { 5.years.ago }

            it { expect { subject }.to_not change { new_employee_working_place.reload.effective_at } }
            it { is_expected.to have_http_status(422) }
          end
        end
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:id) { join_table.id }
    let!(:join_table) do
      create(:employee_working_place,
        employee: employee, working_place: working_place, effective_at: Time.now)
    end
    subject { delete :destroy, { id: id } }

    context 'with valid params' do
      context 'when they are no join tables with the same resources before and after' do
        it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(-1) }

        it { is_expected.to have_http_status(204) }
      end

      context 'when they are join tables with the same resources before and after' do
        let!(:same_resource_tables) do
          [Time.now - 1.week, Time.now + 1.week].map do |date|
            create(:employee_working_place,
              employee: employee, working_place: working_place, effective_at: date)
          end
        end

        it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(-2) }

        it { is_expected.to have_http_status(204) }
      end

      context 'when there is employee balance but its effective at is before resource\'s' do
        let(:employee_balance) do
          create(:employee_balance, :with_time_off, employee: employee,
            effective_at: join_table.effective_at - 5.days)
        end

        it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(-1) }

        it { is_expected.to have_http_status(204) }
      end
    end

    context 'with invalid params' do
      context 'with invalid id' do
        let(:id) { '1ab' }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when EmployeeWorkingPlace belongs to other account' do
        before { employee_working_place.employee.update!(account: create(:account)) }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when they are employee balances after employee_working_place effective at' do
        let!(:employee_balance) do
          create(:employee_balance, :with_time_off, employee: employee,
            effective_at: join_table.effective_at + 5.days)
        end

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { is_expected.to have_http_status(403) }
      end

      context 'when user is not an account manager' do
        before { Account::User.current.update!(account_manager: false, employee: employee) }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { is_expected.to have_http_status(403) }

        it 'have valid error message' do
          subject

          expect(response.body).to include 'You are not authorized to access this page.'
        end
      end
    end
  end
end
