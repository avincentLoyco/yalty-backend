require 'rails_helper'

RSpec.describe HolidaysForEmployeeSchedule, type: :service do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  subject { described_class.new(employee, Time.now.today , Time.now.today + 1.days ).call }

  let (:account) { create(:account) }
  let (:presence_policy) { create(:presence_policy, account: account) }
  let (:second_presence_presence_policy) { create(:presence_policy, account: account) }
  let (:employee) do
     create(:employee ,:with_presence_policy, presence_policy: presence_policy, account: account)
  end

  describe '#call' do

    context 'when the employee has many presence policies active during the period given' do
      let (:second_employee) do
         create(:employee ,:with_presence_policy,
           presence_policy: second_presence_presence_policy, account: account
         )
      end

      context 'and the presence policies have related time entries' do
        let(:second_epp) do
          create(:employee_presence_policy,
            presence_policy: second_presence_presence_policy,
            employee: employee,
            effective_at: Time.now.today + 1.day
          )
        end
        let(:presence_days) do
          [5,6].map do |i|
            create(:presence_day, order: i, presence_policy: presence_policy)
          end
        end
        let(:presence_second_policy) do
          [6,7].map do |i|
            create(:presence_day, order: i, presence_policy: second_presence_presence_policy)
          end
        end
        let!(:time_entries) do
          presence_days.map do |presence_day|
            create(:time_entry, presence_day: presence_second_policy, start_time: '1:00', end_time: '2:00')
          end
        end

        let!(:time_entries) do
          presence_days.map do |presence_day|
            create(:time_entry, presence_day: presence_day, start_time: '8:00', end_time: '9:00')
          end
        end

        it '' do
          expect( subject).to eq(
             {
               '2016-01-01' => [
                 {
                   :type => "working_hours",
                   :start_time => '08:00:00',
                   :end_time => '09:00:00'
                 },
               ],
               '2016-01-02' => [
                 {
                   :type => "working_hours",
                   :start_time => '01:00:00',
                   :end_time => '02:00:00'
                 },
               ]
             }
          )
        end
      end
    end

    context 'when a policy repeats days with same day order' do
      subject { described_class.new(employee, Time.now.today , Time.now.today + 7.days ).call }

      let(:presence_day) do
        create(:presence_day, order: 5, presence_policy: presence_policy)
      end
      let!(:time_entry) do
        create(:time_entry, presence_day: presence_policy, start_time: '1:00', end_time: '2:00')
      end

      it '' do
        expect( subject).to eq(
           {
             '2016-01-01' => [
               {
                 :type => "working_hours",
                 :start_time => '08:00:00',
                 :end_time => '09:00:00'
               }
             ],
             '2016-01-02' => [

             ],
             '2016-01-03' => [

             ],
             '2016-01-04' => [

             ],
             '2016-01-05' => [

             ],
             '2016-01-06' => [

             ],
             '2016-01-07' => [

             ],
             '2016-01-08' => [
               {
                 :type => "working_hours",
                 :start_time => '08:00:00',
                 :end_time => '09:00:00'
               }
             ],
           }
        )
      end
    end

    context 'when there employee have no associated time entries' do
      it '' do
        expect( subject).to eq(
           {
             '2016-01-01' => [

             ],
             '2016-01-02' => [
             ]
           }
        )
      end
    end
  end
end
