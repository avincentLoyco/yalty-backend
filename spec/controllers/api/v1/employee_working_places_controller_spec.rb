require 'rails_helper'

RSpec.describe API::V1::EmployeeWorkingPlacesController, type: :controller do
  include_context 'shared_context_headers'

  let!(:employee) { create(:employee, account: Account.current) }
  let(:new_employee) { create(:employee, account: Account.current) }
  let!(:employee_working_place) { employee.first_employee_working_place }

  describe 'get #INDEX' do
    before { employee_working_place.update!(effective_at: Time.now + 1.day) }

    let!(:working_place_related) do
      create(:employee_working_place,
        working_place: employee_working_place.working_place, effective_at: Time.now + 1.week,
        employee: new_employee
      )
    end
    let!(:employee_related) do
      create(:employee_working_place, employee: employee, effective_at: Time.now + 1.week)
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
  end

  describe 'post #CREATE' do
    subject { post :create, params }
    let(:working_place) { create(:working_place, account: Account.current) }
    let(:effective_at) { Time.zone.now + 1.month }
    let(:employee_id) { employee.id }
    let(:working_place_id) { working_place.id }
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

      context 'when effective already taken' do
        let(:effective_at) { employee_working_place.effective_at }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { is_expected.to have_http_status(422) }
      end

      context 'when effective at before first working place effective at' do
        let(:effective_at) { employee_working_place.effective_at - 1.month }

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { is_expected.to have_http_status(422) }
      end
    end
  end
end
