require 'rails_helper'

RSpec.describe HolidaysForEmployeeSchedule, type: :service do
  include_context 'shared_context_account_helper'

  before do
    employee.first_employee_working_place.update!(effective_at: '1/1/2015')
    employee.first_employee_working_place.working_place.update!(holiday_policy: policy)
  end

  let(:employee) { create(:employee) }
  let(:policy) { create(:holiday_policy, country: 'ch', region: 'zh') }

  subject { described_class.new(employee, range_start, range_end).call }

  context 'when employee has holidays in given range' do
    let(:range_start) { Date.new(2015, 12, 24) }
    let(:range_end) { Date.new(2016, 1, 1) }

    context 'when all holodays have names' do
      it { expect(subject.size).to eq 9 }
      it 'should have valid format' do
        expect(subject).to eq(
          {
            "2015-12-24" => [],
            "2015-12-25" => [
              {
                :type=>"holiday",
                :name=>"christmas"
              }
            ],
            "2015-12-26" => [
              {
                :type=>"holiday",
                :name=>"st_stephens_day"
              }
            ],
            "2015-12-27" => [],
            "2015-12-28" => [],
            "2015-12-29" => [],
            "2015-12-30" => [],
            "2015-12-31" => [],
            "2016-01-01" => [
              {
                :type=>"holiday",
                :name=>"new_years_day"
              }
            ],
          }
        )
      end
    end

    context 'when some of the holidays do not have names' do
      let(:policy) { create(:holiday_policy, country: 'pl') }

      it { expect(subject.size).to eq 9 }
      it 'should have valid format' do
        expect(subject).to eq(
          {
            "2015-12-24" => [],
            "2015-12-25" => [
              {
                :type=>"holiday",
                :name=> nil
              }
            ],
            "2015-12-26" => [
              {
                :type=>"holiday",
                :name=> nil
              }
            ],
            "2015-12-27" => [],
            "2015-12-28" => [],
            "2015-12-29" => [],
            "2015-12-30" => [],
            "2015-12-31" => [],
            "2016-01-01" => [
              {
                :type=>"holiday",
                :name=> nil
              }
            ],
          }
        )
      end
    end
  end

  context 'when employee does not have holodays in given range' do
    let(:range_start) { Date.new(2015, 2, 2) }
    let(:range_end) { Date.new(2015, 2, 5) }

    it { expect(subject.size).to eq 4 }
    it 'should have valid format' do
      expect(subject).to eq(
        {
          "2015-02-02" => [],
          "2015-02-03" => [],
          "2015-02-04" => [],
          "2015-02-05" => [],
        }
      )
    end
  end
end
