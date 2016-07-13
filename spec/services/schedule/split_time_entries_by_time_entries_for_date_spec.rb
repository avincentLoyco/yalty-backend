require 'rails_helper'

RSpec.describe SplitTimeEntriesByTimeEntriesForDate, type: :service do

  let(:time_entries_to_split) do
    [
      {
        :type => 'working_time',
        :start_time => "00:00:00",
        :end_time => "05:00:00"
      }
    ]
  end

  let(:time_entries_to_base_the_split) do
    [
      {
        :type => 'working_time',
        :start_time => "00:00:00",
        :end_time => "01:00:00"
      },
      {
        :type => 'working_time',
        :start_time => "02:00:00",
        :end_time => "03:00:00"
      },
      {
        :type => 'working_time',
        :start_time => "04:00:00",
        :end_time => "05:00:00"
      }
    ]
  end

  subject do
    described_class.new(time_entries_to_split,time_entries_to_base_the_split, 'working_time').call
  end

  describe "#call" do

    context 'when there are time entries to split and to be split by' do
      it '' do
        expect(subject).to match_hash(
        [
          {
            :type => 'working_time',
            :start_time => "01:00:00",
            :end_time => "02:00:00"
          },
          {
            :type => 'working_time',
            :start_time => "03:00:00",
            :end_time => "04:00:00"
          }
        ]

        )
      end
    end

    context 'when there are no time entries to split by' do
      let(:time_entries_to_base_the_split) { [] }
      it '' do
        expect(subject).to match_hash(
          [
            {
              :type => 'working_time',
              :start_time => "00:00:00",
              :end_time => "05:00:00"
            }
          ]
        )
      end
    end
    context 'when there are no entries to be split' do
      let(:time_entries_to_split) { [] }
      it '' do
        expect(subject).to eql([])
      end
    end
  end
end
