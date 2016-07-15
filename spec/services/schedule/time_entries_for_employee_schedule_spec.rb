require 'rails_helper'

RSpec.describe TimeEntriesForEmployeeSchedule, type: :service do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  subject { described_class.new(employee, Time.zone.today , Time.zone.today + 1.days ).call }

  let (:account) { create(:account) }
  let (:presence_policy) { create(:presence_policy, account: account) }
  let (:second_presence_presence_policy) { create(:presence_policy, account: account) }
  let (:employee) do
     create(:employee ,:with_presence_policy, presence_policy: presence_policy, account: account)
  end

  describe '#call' do

    context 'when the employee has many presence policies active during the period given' do

      context 'and the presence policies have related time entries' do
        let(:effective_at) { Time.zone.today + 1.day}
        let!(:second_epp) do
          create(:employee_presence_policy,
            presence_policy: second_presence_presence_policy,
            employee: employee,
            effective_at: effective_at
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
        before(:each) do
          presence_second_policy.map do |presence_day|
            create(:time_entry, presence_day: presence_day, start_time: '1:00', end_time: '2:00')
            create(:time_entry, presence_day: presence_day, start_time: '2:00', end_time: '3:00')
          end
          presence_days.map do |presence_day|
            create(:time_entry, presence_day: presence_day, start_time: '8:00', end_time: '9:00')
          end
        end
        it 'and the period is smaller than a week' do
          expect( subject).to match_hash(
             {
               '2016-01-01' => [
                 {
                   :type => "working_time",
                   :start_time => '08:00:00',
                   :end_time => '09:00:00'
                 },
               ],
               '2016-01-02' => [
                 {
                   :type => "working_time",
                   :start_time => '02:00:00',
                   :end_time => '03:00:00'
                 },
                 {
                   :type => "working_time",
                   :start_time => '01:00:00',
                   :end_time => '02:00:00'
                 },

               ]
             }
          )
        end
      end
    end

    context 'when the employee has one one presence policy during the period' do

      context 'when a policy is longer than one week' do
        subject { described_class.new(employee, Time.zone.today , Time.zone.today + 7.days ).call }

        let(:presence_days) do
          [5,6].map do |i|
            create(:presence_day, order: i, presence_policy: presence_policy)
          end
        end
        before(:each) do
          create(:time_entry, presence_day: presence_days[0], start_time: '8:00', end_time: '9:00')
          create(:time_entry, presence_day: presence_days[0], start_time: '6:00', end_time: '7:00')
          create(:time_entry, presence_day: presence_days[1], start_time: '1:00', end_time: '2:00')

        end

        it '' do
          expect( subject).to match_hash(
             {
               '2016-01-01' => [
                 {
                   :type => "working_time",
                   :start_time => '06:00:00',
                   :end_time => '07:00:00'
                 },
                 {
                   :type => "working_time",
                   :start_time => '08:00:00',
                   :end_time => '09:00:00'
                 }
               ],
               '2016-01-02' => [
                 {
                   :type => "working_time",
                   :start_time => '01:00:00',
                   :end_time => '02:00:00'
                 }
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
                   :type => "working_time",
                   :start_time => '06:00:00',
                   :end_time => '07:00:00'
                 },
                 {
                   :type => "working_time",
                   :start_time => '08:00:00',
                   :end_time => '09:00:00'
                 }

               ],
             }
          )
        end
      end

      context 'when the employee time entries that are present and some that are not in the requested range' do

        let(:presence_day) do
          create(:presence_day, order: 1, presence_policy: presence_policy)
        end
        let(:second_presence_day) do
          create(:presence_day, order: 5, presence_policy: presence_policy)
        end

        before(:each) do
          create(:time_entry, presence_day: presence_day, start_time: '1:00', end_time: '2:00')
          create(:time_entry, presence_day: second_presence_day, start_time: '8:00', end_time: '9:00')
        end

        it '' do
          expect( subject).to match_hash(
             {
               '2016-01-01' => [
                 {
                   :type => "working_time",
                   :start_time => '08:00:00',
                   :end_time => '09:00:00'
                 }
               ],
               '2016-01-02' => [
               ]
             }
          )
        end
      end

      context 'when the start day order is' do
        let(:presence_days) do
          [1,4,5].map do |i|
            create(:presence_day, order: i, presence_policy: presence_policy)
          end
        end
        before(:each) do
          presence_days.each do |presence_day|
            create(:time_entry, presence_day: presence_day, start_time: '1:00', end_time: '2:00')
          end

        end
        context 'bigger than the end day order' do
          let(:start_date) { Date.new(2016,1,6) }
          subject { described_class.new(employee, start_date , start_date + 6.days ).call }

          it '' do
            expect( subject).to match_hash(
               {
                 '2016-01-06' => [],
                 '2016-01-07' => [
                   {
                     :type => "working_time",
                     :start_time => '01:00:00',
                     :end_time => '02:00:00'
                   }
                 ],
                 '2016-01-08' => [
                   {
                     :type => "working_time",
                     :start_time => '01:00:00',
                     :end_time => '02:00:00'
                   }
                 ],
                 '2016-01-09' => [],
                 '2016-01-10' => [],
                 '2016-01-11' => [
                   {
                     :type => "working_time",
                     :start_time => '01:00:00',
                     :end_time => '02:00:00'
                   }
                 ],
                 '2016-01-12' => []
               }
            )
          end
        end

        context 'smaller than the end day order' do
          let(:start_date) { Date.new(2016,1,8) }
          subject { described_class.new(employee, start_date , start_date + 8.days ).call }

          it '' do
            expect( subject).to match_hash(
              {
                '2016-01-08' => [
                  {
                    :type => "working_time",
                    :start_time => '01:00:00',
                    :end_time => '02:00:00'
                  }
                ],
                '2016-01-09' => [],
                '2016-01-10' => [],
                '2016-01-11' => [
                  {
                    :type => "working_time",
                    :start_time => '01:00:00',
                    :end_time => '02:00:00'
                  }
                ],
                '2016-01-12' => [],
                '2016-01-13' => [],
                '2016-01-14' => [
                  {
                    :type => "working_time",
                    :start_time => '01:00:00',
                    :end_time => '02:00:00'
                  }
                ],
                '2016-01-15' => [
                  {
                    :type => "working_time",
                    :start_time => '01:00:00',
                    :end_time => '02:00:00'
                  }
                ],
                '2016-01-16' => []
              }
            )
          end
        end

        context 'equal than the day order' do
          let(:start_date) { Date.new(2016,1,4) }
          subject { described_class.new(employee, start_date , start_date + 7 .days ).call }

          it '' do
            expect( subject).to match_hash(
               {
                 '2016-01-04' => [
                   {
                     :type => "working_time",
                     :start_time => '01:00:00',
                     :end_time => '02:00:00'
                   }
                 ],
                 '2016-01-05' => [],
                 '2016-01-06' => [],
                 '2016-01-07' => [
                   {
                     :type => "working_time",
                     :start_time => '01:00:00',
                     :end_time => '02:00:00'
                   }
                 ],
                 '2016-01-08' => [
                   {
                     :type => "working_time",
                     :start_time => '01:00:00',
                     :end_time => '02:00:00'
                   }
                 ],
                 '2016-01-09' => [],
                 '2016-01-10' => [],
                 '2016-01-11' => [
                   {
                     :type => "working_time",
                     :start_time => '01:00:00',
                     :end_time => '02:00:00'
                   }
                 ]

               }
            )
          end
        end

      end
    end


  end
end
