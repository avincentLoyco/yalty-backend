require 'rails_helper'

RSpec.describe API::V1::SchedulesController , type: :controller do
  include_context 'shared_context_headers'
  include_context 'shared_context_timecop_helper'

  describe 'GET #show' do
    let(:working_place) { create(:working_place, account: account, holiday_policy: policy) }
    let(:employee) { create(:employee, account: account, employee_working_places: [ewp]) }
    let(:policy) { create(:holiday_policy, country: 'ch', region: 'zh', ) }
    let(:employee_id) { employee.id }
    let(:from) { '25.12.2015' }
    let(:to) { '27.12.2015' }
    let(:params) {{ employee_id: employee_id, from: from, to: to }}
    let(:ewp) do
      create(:employee_working_place, working_place: working_place, effective_at: '1/1/2015')
    end

    subject { get :schedule_for_employee, params }

    context 'with valid params' do
      before do
        presence_days.map do |presence_day|
          create(:time_entry, presence_day: presence_day, start_time: '1:00', end_time: '24:00')
        end
        create(:employee_presence_policy,
          presence_policy: presence_policy, employee: employee, effective_at: '1/1/2015')
      end

      let(:presence_policy) { create(:presence_policy, account: account) }
      let!(:time_off) do
        create(:time_off,
          employee: employee,
          start_time: Time.now - 5.days + 3.hours,
          end_time: Time.now - 5.days + 5.hours
        )
      end
      let(:presence_days)  do
        [1,2,3,4,5,6,7].map do |i|
          create(:presence_day, order: i, presence_policy: presence_policy)
        end
      end

      it { is_expected.to have_http_status(200) }
      it 'should have valid response body' do
        subject
        expect(JSON.parse(response.body)).to eq(
          [
            {
              'date' => '2015-12-25',
              'time_entries' => [
                {
                  'type' => 'holiday',
                  'name' => 'christmas'
                }
              ]
            },
            {
              'date' => '2015-12-26',
              'time_entries' => [
                {
                  'type' => 'holiday',
                  'name' => 'st_stephens_day'
                }
              ]
            },
            {
              'date' => '2015-12-27',
              'time_entries' => [
                {
                  'type' => 'time_off',
                  'name' => time_off.time_off_category.name,
                  'start_time' => '03:00:00',
                  'end_time' => '05:00:00'
                },
                {
                  'type' => 'working_time',
                  'start_time' => '01:00:00',
                  'end_time' => '03:00:00'
                },
                {
                  'type' => 'working_time',
                  'start_time' => '05:00:00',
                  'end_time' => '24:00:00'
                }
              ]
            }
          ]
        )
      end

      context 'when account user is not account manager but he has employee with given id' do
        before { Account::User.current.update!(account_manager: false, employee: employee) }

        it { is_expected.to have_http_status(200) }
      end
    end

    context 'with invalid params' do
      shared_examples 'ScheduleForEmployee not called' do
        it 'should call ScheduleForEmployee service' do
          expect(ScheduleForEmployee).to_not receive(:new)
          subject
        end
      end

      context 'when invalid employee id send' do
        let(:employee_id) { 'abc' }

        it_behaves_like 'ScheduleForEmployee not called'
        it { is_expected.to have_http_status(404) }
      end

      context 'when employee id does not belong to employee and user is not account manager' do
        before { Account::User.current.update!(account_manager: false) }

        it_behaves_like 'ScheduleForEmployee not called'
        it { is_expected.to have_http_status(403) }
      end

      context 'when from params is not a valid date' do
        let(:from) { 'abc' }

        it_behaves_like 'ScheduleForEmployee not called'
        it { is_expected.to have_http_status(422) }
        it 'should have valid response body' do
          subject

          expect(response.body).to include 'From and to params must be in date format'
        end
      end

      context 'when to params is not a valid date' do
        let(:from) { 'to' }

        it_behaves_like 'ScheduleForEmployee not called'
        it { is_expected.to have_http_status(422) }
        it 'should have valid response body' do
          subject

          expect(response.body).to include 'From and to params must be in date format'
        end
      end

      context 'missing params' do
        context 'when from param not send' do
          before { params.delete(:from) }

          it_behaves_like 'ScheduleForEmployee not called'
          it { is_expected.to have_http_status(422) }
        end

        context 'when to param not send' do
          before { params.delete(:to) }

          it_behaves_like 'ScheduleForEmployee not called'
          it { is_expected.to have_http_status(422) }
        end
      end
    end
  end
end
