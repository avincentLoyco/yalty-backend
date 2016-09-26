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
        let!(:first_epp) do
          create(:employee_presence_policy, employee: employee, presence_policy: time_off_policy,
            effective_at: Date.today
          )
        end
        let!(:lastest_epp) do
          create(:employee_presence_policy, employee: employee, effective_at: Date.today + 1.week)
        end
        context 'and the effective at is equal to the lastest EWP effective_at' do
          let(:effective_at) { lastest_epp.effective_at }
          context 'and the presence policy is the same as the oldest EWP' do
            it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(-1) }
            it { expect { subject }.to change { Employee::Balance.count }.by(-1) }
          end
          context "and the presence policy is different than the exisitng EWP's ones" do
            let(:presence_policy_id) { create(:presence_policy, account: account).first }

            it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
            it { expect { subject }.to_not change { Employee::Balance.count } }
          end
        end
        context 'and the effective at is before the lastest EWP effective_at' do
          let(:effective_at) { lastest_epp.effective_at - 2.days }
          context 'and the presence policy is the same as the oldest EWP' do
            it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
            it { expect { subject }.to_not change { Employee::Balance.count } }
          end
          context "and the presence policy is different than the exisitng EWP's ones" do
            let(:presence_policy_id) { create(:presence_policy, account: account).first }

            it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(1) }
            it { expect { subject }.to change { Employee::Balance.count }.by(1) }
          end
        end
        context 'and the effective at is after than the lastest EWP effective_at' do
          let(:effective_at) { lastest_epp.effective_at }
          context 'and the presence policy is the same as the oldest EWP' do
            it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(1) }
            it { expect { subject }.to change { Employee::Balance.count }.by(1) }
          end
          context "and the presence policy is different than the exisitng EWP's ones" do
            let(:presence_policy_id) { create(:presence_policy, account: account).first }

            it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(1) }
            it { expect { subject }.to change { Employee::Balance.count }.by(1) }
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
      create(:employee_working_place, employee: employee, effective_at: 2.days.ago)
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
        let!(:first_epp) do
          create(:employee_presence_policy, employee: employee, presence_policy: time_off_policy,
            effective_at: Date.today
          )
        end
        let!(:lastest_epp) do
          create(:employee_presence_policy, employee: employee, effective_at: Date.today + 1.week)
        end
        context 'and the effective at is equal to the lastest EWP effective_at' do
          let(:effective_at) { lastest_epp.effective_at }
          context 'and the presence policy is the same as the oldest EWP' do
            it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(-1) }
            it { expect { subject }.to change { Employee::Balance.count }.by(-1) }
          end
          context "and the presence policy is different than the exisitng EWP's ones" do
            let(:presence_policy_id) { create(:presence_policy, account: account).first }

            it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
            it { expect { subject }.to_not change { Employee::Balance.count } }
          end
        end
        context 'and the effective at is before the lastest EWP effective_at' do
          let(:effective_at) { lastest_epp.effective_at - 2.days }
          context 'and the presence policy is the same as the oldest EWP' do
            it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
            it { expect { subject }.to_not change { Employee::Balance.count } }
          end
          context "and the presence policy is different than the exisitng EWP's ones" do
            let(:presence_policy_id) { create(:presence_policy, account: account).first }

            it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(1) }
            it { expect { subject }.to change { Employee::Balance.count }.by(1) }
          end
        end
        context 'and the effective at is after than the lastest EWP effective_at' do
          let(:effective_at) { lastest_epp.effective_at }
          context 'and the presence policy is the same as the oldest EWP' do
            it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(1) }
            it { expect { subject }.to change { Employee::Balance.count }.by(1) }
          end
          context "and the presence policy is different than the exisitng EWP's ones" do
            let(:presence_policy_id) { create(:presence_policy, account: account).first }

            it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(1) }
            it { expect { subject }.to change { Employee::Balance.count }.by(1) }
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

      context 'when there is employee balance' do
        before do
          create(:employee_balance, :with_time_off,
            employee: employee, effective_at: balance_effective_at)
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
          let(:effective_at) { 5.years.ago }
          let(:balance_effective_at) { 5.days.ago }

          it { expect { subject }.to_not change { new_employee_working_place.reload.effective_at } }
          it { is_expected.to have_http_status(422) }

          it 'has valid error in response body' do
            subject

            expect(response.body).to include 'Employee balance after effective at already exists'
          end
        end
      end
    end
  end
end
