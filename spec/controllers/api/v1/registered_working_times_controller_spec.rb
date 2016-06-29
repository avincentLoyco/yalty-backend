require 'rails_helper'

RSpec.describe API::V1::RegisteredWorkingTimesController, type: :controller do
  include_context 'shared_context_headers'

  describe '#create' do
    subject { post :create, params }
    let(:employee) { create(:employee, account: Account.current) }
    let(:employee_id) { employee.id }
    let(:date) { '1/4/2016' }
    let(:first_start_time) { '15:00' }
    let(:first_end_time) { '19:00' }
    let(:params) do
      {
        employee_id: employee_id,
        date: date,
        time_entries: time_entries_params
      }
    end
    let(:time_entries_params) do
      [
        {
          'start_time' =>'11:00',
          'end_time' => '15:00',
          'type' => 'working_time'
        },
        {
          'start_time' => first_start_time,
          'end_time' => first_end_time,
          'type' => 'working_time'
        }
      ]
    end

    shared_examples '' do
    end

    context 'with valid params' do
      shared_examples 'Authorized employee' do
        before { Account::User.current.update!(account_manager: false, employee: employee) }

        it { is_expected.to have_http_status(204) }
      end

      context 'when data for time entries is empty' do
        let(:time_entries_params) { [{}] }

        it { expect { subject }.to change { RegisteredWorkingTime.count }.by(1) }
        it { expect { subject }.to change { employee.registered_working_times.count }.by(1) }

        it { is_expected.to have_http_status(204) }
        it_behaves_like 'Authorized employee'
      end

      context 'when registered working time for a given date does not exist' do
        it { expect { subject }.to change { RegisteredWorkingTime.count }.by(1) }
        it { expect { subject }.to change { employee.registered_working_times.count }.by(1) }

        it { is_expected.to have_http_status(204) }
        it_behaves_like 'Authorized employee'
      end

      context 'when registered working time for a given date exists' do
        let!(:registered_working_time) do
          create(:registered_working_time, employee: employee, date: date)
        end

        it { expect { subject }.to_not change { RegisteredWorkingTime.count } }
        it { expect { subject }.to change { registered_working_time.reload.time_entries } }

        it { is_expected.to have_http_status(204) }
        it_behaves_like 'Authorized employee'

        it 'should have new time entries' do
          subject

          expect(registered_working_time.reload.time_entries).to include(
            'start_time' =>'11:00', 'end_time' =>'15:00',
          )

          expect(registered_working_time.reload.time_entries).to include(
            'start_time' =>'15:00', 'end_time' =>'19:00',
          )
        end
      end
    end

    context 'with invalid params' do
      context 'when user is not an account manager or resource owner' do
        before { Account::User.current.update!(account_manager: false) }

        it { expect { subject }.to_not change { RegisteredWorkingTime.count } }
        it { is_expected.to have_http_status(403) }
      end

      context 'when invalid date format send' do
        let(:date) { 'abc' }

        it { expect { subject }.to_not change { RegisteredWorkingTime.count } }
        it { is_expected.to have_http_status(422) }
      end

      context 'when ivalid data for time entries send' do
        context 'time entries times are not valid' do
          let(:first_start_time) { 'abcd' }
          let(:first_end_time) { 'efgh' }

          it { expect { subject }.to_not change { RegisteredWorkingTime.count } }
          it { is_expected.to have_http_status(422) }
        end

        context 'time entries times are not present' do
          let(:first_start_time) { '' }
          let(:first_end_time) { nil }

          it { expect { subject }.to_not change { RegisteredWorkingTime.count } }
          it { is_expected.to have_http_status(422) }
        end

        context 'invalid time_entries keys' do
          let(:time_entries_params) do
            [
              {
                'test' =>'11:00',
                'test2' => '15:00'
              },
              []
            ]
          end

          it { expect { subject }.to_not change { RegisteredWorkingTime.count } }
          it { is_expected.to have_http_status(422) }
        end

        context 'invalid time entries format' do
          let(:time_entries_params) do
            [
              {
                'start_time' =>'11:00',
                'end_time' => '15:00'
              },
              []
            ]
          end

          it { expect { subject }.to_not change { RegisteredWorkingTime.count } }
          it { is_expected.to have_http_status(422) }
        end
      end

      context 'when invalid employee id send' do
        let(:employee_id) { 'abc' }

        it { expect { subject }.to_not change { RegisteredWorkingTime.count } }
        it { is_expected.to have_http_status(404) }
      end
    end
  end
end
