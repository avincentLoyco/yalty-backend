require 'rails_helper'

RSpec.describe Adjustments::Calculate, type: :service do
  include_context 'shared_context_timecop_helper'

  let(:employee) { create(:employee, hired_at: hired_date, contract_end_at: contract_end_date) }
  let(:hired_date) { Date.new(2017, 6, 26) }
  let(:contract_end_date) { nil }
  let(:vacation_category) { employee.account.time_off_categories.find_by(name: "vacation") }
  let(:time_off_policy) do
    create(:time_off_policy, amount: 9600, time_off_category: vacation_category) # 160 h
  end
  let(:time_off_policy_with_different_amount) do
    create(:time_off_policy, amount: 14400, time_off_category: vacation_category ) # 240 h
  end
  let(:time_off_policy_with_start_date) do
    create(:time_off_policy, amount: 9600, time_off_category: vacation_category,
      start_day: 1, start_month: 6)
  end
  let(:days_to_minutes) { 24 * 60 }

  let(:create_new_etop) do
    create(:employee_time_off_policy,
      employee: employee,
      time_off_policy: time_off_policy,
      effective_at: Date.new(2017, 6, 26),
      occupation_rate: 0.5)
  end

  let(:create_new_etop_different_or) do
    create(:employee_time_off_policy,
      employee: employee,
      time_off_policy: time_off_policy,
      effective_at: Date.new(2017, 6, 26),
      occupation_rate: 0.8)
  end

  let(:create_new_etop_with_different_occupation_rate) do
    create(:employee_time_off_policy,
      employee: employee,
      time_off_policy: time_off_policy_with_different_amount,
      effective_at: Date.new(2017, 6, 26),
      occupation_rate: 0.8)
  end

  let(:create_new_etop_with_different_top) do
    create(:employee_time_off_policy,
      employee: employee,
      time_off_policy: time_off_policy_with_different_amount,
      effective_at: Date.new(2017, 6, 26),
      occupation_rate: 0.5)
  end

  let(:create_etop_on_top_start_date) do
    create(:employee_time_off_policy,
      employee: employee,
      time_off_policy: time_off_policy_with_start_date,
      effective_at: Date.new(2017, 6, 1),
      occupation_rate: 0.5)
  end

  let(:create_previous_etop) do
    create(:employee_time_off_policy,
      employee: employee,
      time_off_policy: time_off_policy,
      effective_at: Date.new(2017, 6, 1),
      occupation_rate: 0.5)
  end

  subject { described_class.new(employee.id).call }

  context 'when hired event' do
    context 'and etop is assigned on different date than start date of time off policy' do
      before do
        create_new_etop
      end

      let(:number_of_days_until_end_of_year) { 189 }
      let(:annual_allowance) { 9600 * 0.5 / 60.0 / 24.0 } # in days
      it do
        expect(subject).to eql((annual_allowance / 365.0 *
          number_of_days_until_end_of_year * days_to_minutes).round)
      end
    end
    context 'and etop is assigned on start date of time off policy' do
      before do
        create_etop_on_top_start_date
      end
      let(:hired_date) { Date.new(2017, 6, 1) }
      let(:number_of_days_until_end_of_year) { 214 }
      let(:annual_allowance) { 9600 * 0.5 / 60.0 / 24.0 } # in days
      it do
        expect(subject).to eql((annual_allowance / 365.0 *
          number_of_days_until_end_of_year * days_to_minutes).round)
      end
    end
  end

  context 'when work contract event' do
    let(:hired_date) { Date.new(2017, 6, 1) }
    before do
      create_previous_etop
    end
    context 'and time off policy did not change' do
      context 'and occupation rate did not change' do
        before do
          create_new_etop
        end
        it do
          expect(subject).to eql(0)
        end
      end
      context 'and occupation rate has changed' do
        before do
          create_new_etop_different_or
        end
        let(:number_of_days_until_end_of_year) { 189 }
        let(:previous_annual_allowance) { 9600 * 0.5 / 60.0 / 24.0 }
        let(:current_annual_allowance) { 9600 * 0.8 / 60.0 / 24.0 }
        let(:calculations) { ((-previous_annual_allowance + current_annual_allowance) /
          365.0 * number_of_days_until_end_of_year * days_to_minutes).round }
        it do
          expect(subject).to eql(calculations)
        end
      end
    end
    context 'and time off policy has changed' do
      context 'and occupation rate did not change' do
        before do
          create_new_etop_with_different_top
        end

        let(:number_of_days_until_end_of_year) { 189 }
        let(:previous_annual_allowance) { 9600 * 0.5 / 60.0 / 24.0 }
        let(:current_annual_allowance) { 14400 * 0.5 / 60.0 / 24.0 }
        it do
          expect(subject).to eql(((-previous_annual_allowance + current_annual_allowance) / 365.0 *
            number_of_days_until_end_of_year * days_to_minutes).round)
        end
      end
      context 'and occupation rate has changed' do
        before do
          create_new_etop_with_different_occupation_rate
        end
        let(:number_of_days_until_end_of_year) { 189 }
        let(:previous_annual_allowance) { 9600 * 0.5 / 60.0 / 24.0 }
        let(:current_annual_allowance) { 14400 * 0.8 / 60.0 / 24.0 }
        it do
          expect(subject).to eql(((-previous_annual_allowance + current_annual_allowance) / 365.0 *
            number_of_days_until_end_of_year * days_to_minutes).round)
        end
      end
    end
  end
  context 'when contract end event' do
    before do
      create_previous_etop
    end
    let(:hired_date) { Date.new(2017, 6, 1) }
    let(:contract_end_date) { Date.new(2017, 8, 1) }
    let(:number_of_days_until_end_of_year) { 153 } # days from contract_end to end of year
    let(:annual_allowance_in_days) { 9600 * 0.5 / 60.0 / 24.0 }
    it do
      expect(subject).to eql((number_of_days_until_end_of_year * -annual_allowance_in_days / 365 *
        days_to_minutes).round)
    end
  end
end
