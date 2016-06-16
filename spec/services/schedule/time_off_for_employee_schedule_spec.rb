require 'rails_helper'

RSpec.describe TimeOffForEmployeeSchedule, type: :service do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  subject { described_class.new(employee, start_date, end_date).call }
  let(:start_date) { Date.new(2016, 1, 1) }
  let(:end_date) { Date.new(2016, 1, 3) }
  let(:employee) { create(:employee) }
  let(:category_name) { time_offs_in_range.first.time_off_category.name }

  context 'when employee does not have time offs in given range' do
    let(:time_offs_in_range) { [] }

    it { expect(subject.size).to eq 3 }
    it 'should have valid format' do
      expect(subject).to eq (
        {
          "2016-01-01" => [],
          "2016-01-02" => [],
          "2016-01-03" => []
        }
      )
    end
  end

  context 'when employee has time offs in given range' do
    context 'when their start time or end time is outside given range' do
      let!(:time_offs_in_range) do
        [create(:time_off,
          start_time: Time.zone.now - 2.days, end_time: Time.zone.now + 6.days, employee: employee)]
      end

      it { expect(subject.size).to eq 3 }
      it 'should have valid format' do
        expect(subject).to eq (
          {
            "2016-01-01" => [
              {
                :type => "time_off",
                :name => category_name,
                :start_time => "00:00:00",
                :end_time => "23:59:59"
              }
            ],
            "2016-01-02" => [
              {
                :type => "time_off",
                :name => category_name,
                :start_time => "00:00:00",
                :end_time => "23:59:59"
              }
            ],
            "2016-01-03" => [
              {
                :type => "time_off",
                :name => category_name,
                :start_time => "00:00:00",
                :end_time => "23:59:59"
              }
            ]
          }
        )
      end
    end

    context 'and they are whole inside given range' do
      context 'and they are shorter than one day' do
        context 'and they are in the same day' do
          let!(:time_offs_in_range) do
            [[Time.zone.now + 2.hours, Time.zone.now + 5.hours],
             [Time.zone.now + 7.hours, Time.zone.now + 12.hours]].map do |start_time, end_time|
               create(:time_off, employee: employee, start_time: start_time, end_time: end_time)
            end
          end

          it { expect(subject.size).to eq 3 }
          it 'should have valid format' do
            expect(subject).to eq (
              {
                "2016-01-01" => [
                  {
                    :type => "time_off",
                    :name => category_name,
                    :start_time => "02:00:00",
                    :end_time => "05:00:00"
                  },
                  {
                    :type => "time_off",
                    :name => category_name,
                    :start_time => "07:00:00",
                    :end_time => "12:00:00"
                  }
                ],
                "2016-01-02" => [],
                "2016-01-03" => []
              }
            )
          end

          context 'and they are more than two time offs in one day' do
            let!(:time_offs_in_range) do
              [[Time.zone.now + 1.hour, Time.zone.now + 4.hours],
               [Time.zone.now + 5.hours, Time.zone.now + 8.hours],
               [Time.zone.now + 9.hours, Time.zone.now + 12.hours],
               [Time.zone.now + 13.hours, Time.zone.now + 16.hours]].map do |start_time, end_time|
                 create(:time_off, employee: employee, start_time: start_time, end_time: end_time)
              end
            end

            it { expect(subject.size).to eq 3 }
            it 'should have valid format' do
              expect(subject).to eq (
                {
                  "2016-01-01" => [
                    {
                      :type => "time_off",
                      :name => category_name,
                      :start_time => "01:00:00",
                      :end_time => "04:00:00"
                    },
                    {
                      :type => "time_off",
                      :name => category_name,
                      :start_time => "05:00:00",
                      :end_time => "08:00:00"
                    },
                    {
                      :type => "time_off",
                      :name => category_name,
                      :start_time => "09:00:00",
                      :end_time => "12:00:00"
                    },
                    {
                      :type => "time_off",
                      :name => category_name,
                      :start_time => "13:00:00",
                      :end_time => "16:00:00"
                    }
                  ],
                  "2016-01-02" => [],
                  "2016-01-03" => []
                }
              )
            end
          end
        end

        context 'and they are in different days' do
          let!(:time_offs_in_range) do
            [[Time.zone.now + 2.hours, Time.zone.now + 5.hours],
             [Time.zone.now + 1.day + 7.hours, Time.zone.now + 1.day + 24.hours]].map do |start_time, end_time|
               create(:time_off, employee: employee, start_time: start_time, end_time: end_time)
            end
          end

          it { expect(subject.size).to eq 3 }
          it 'should have valid format' do
            expect(subject).to eq (
              {
                "2016-01-01" => [
                  {
                    :type => "time_off",
                    :name => category_name,
                    :start_time => "02:00:00",
                    :end_time => "05:00:00"
                  },
                ],
                "2016-01-02" => [
                  {
                    :type => "time_off",
                    :name => category_name,
                    :start_time => "07:00:00",
                    :end_time => "23:59:59"
                  }
                ],
                "2016-01-03" => []
              }
            )
          end
        end
      end

      context 'and they are shorter than two days but longer than one' do
        let!(:time_offs_in_range) do
          [[Time.zone.now + 1.hour, Time.zone.now + 1.day + 2.hours],
           [Time.zone.now + 1.day + 7.hours, Time.zone.now + 2.days + 12.hours]].map do |start_time, end_time|
             create(:time_off, employee: employee, start_time: start_time, end_time: end_time)
           end
        end

        it { expect(subject.size).to eq 3 }
        it 'should have valid format' do
          expect(subject).to eq(
            {
              "2016-01-01" => [
                {
                  :type => "time_off",
                  :name => category_name,
                  :start_time => "01:00:00",
                  :end_time => "23:59:59"
                },
              ],
              "2016-01-02" => [
                {
                  :type => "time_off",
                  :name => category_name,
                  :start_time => "00:00:00",
                  :end_time => "02:00:00"
                },
                {
                  :type => "time_off",
                  :name => category_name,
                  :start_time => "07:00:00",
                  :end_time => "23:59:59"
                }
              ],
              "2016-01-03" => [
                {
                  :type => "time_off",
                  :name => category_name,
                  :start_time => "00:00:00",
                  :end_time => "12:00:00"
                },
              ]
            }
          )
        end
      end
    end
  end
end
