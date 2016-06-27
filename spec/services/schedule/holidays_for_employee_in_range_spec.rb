require 'rails_helper'

RSpec.describe HolidaysForEmployeeInRange, type: :service do
  include_context 'shared_context_timecop_helper'
  before do
    employee.first_employee_working_place.update!(effective_at: '1/1/2015')
    employee.first_employee_working_place.working_place.update!(holiday_policy: holiday_policy)
  end

  let(:employee) { create(:employee) }
  let(:holiday_policy) { create(:holiday_policy, country: 'ch', region: 'zh') }
  subject { described_class.new(employee, start_time, end_time).call }

  context 'when given period is shorter or equal one day' do
    context 'and there are holidays in a period' do
      let(:start_time) { '1/1/2016'.to_date }
      let(:end_time) { '1/1/2016'.to_date }

      it { expect(subject.size).to eq 1 }
      it { expect(subject.first.name).to eq 'new_years_day' }

      context 'and it is shorter than one day' do
        let(:start_time) { '14:00 1/1/2015'.to_time }
        let(:end_time) { '16:00 1/1/2015'.to_time }

        it { expect(subject.size).to eq 1 }
        it { expect(subject.first.name).to eq 'new_years_day' }
      end
    end

    context 'and there are no holidays in a period' do
      let(:start_time) { '4/1/2016'.to_date }
      let(:end_time) { '4/1/2016'.to_date }

      it { expect(subject.size).to eq 0 }
    end
  end

  context 'when given period is longer than one day' do
    context 'and there are holidays in period' do
      let(:start_time) { '24/12/2015'.to_date }
      let(:end_time) { '2/1/2016'.to_date }

      context 'and employee belongs to one working place in a given period' do
        it { expect(subject.size).to eq 4 }
      end

      context 'and employee belongs to more than one working place in a given period' do
        before { new_employee_working_place.working_place.update!(holiday_policy: new_policy) }
        let(:new_employee_working_place) do
          create(:employee_working_place, employee: employee, effective_at: '1/1/2016')
        end

        context 'and employee has the same policy' do
          let(:new_policy) { create(:holiday_policy, country: 'ch', region: 'zh') }

          it { expect(subject.size).to eq 4 }
        end

        context 'and employee has different policies' do
          let(:new_policy) { create(:holiday_policy, country: country, region: region) }

          context 'the same country different regions' do
            let(:country) { 'ch' }
            let(:region) { 'lu' }

            it { expect(subject.size).to eq 4 }
          end

          context 'different country' do
            let(:country) { 'pl' }
            let(:region) { nil }

            it { expect(subject.size).to eq 3 }
          end
        end
      end
    end

    context 'and there are no holidays in period' do
      let(:start_time) { '4/1/2016'.to_date }
      let(:end_time) { '2/2/2016'.to_date }

      it { expect(subject.size).to eq 0 }
    end
  end
end
