require 'rails_helper'

RSpec.describe PeriodsForTimeOffCategory, type: :service do
  subject { described_class.new(employee, category).call }

  let(:employee) { create(:employee) }
  let(:category) { create(:time_off_category, account: employee.account) }

  context 'when employee does not have employee time off policies in category' do
    it { expect(subject).to eq [] }
  end

  context 'when employee has time off policies in category assigned' do
    let!(:policies) do
      [1.week.ago, 1.day.ago, 1.week.since].map do |date|
        create(:employee_time_off_policy,
          employee: employee, effective_at: date,
          time_off_policy: create(:time_off_policy, time_off_category: category))
      end
    end

    context 'and he does not have contract end' do
      it do
        expect(subject).to eq(
          [
            {
              effective_since: policies.first.effective_at,
              effective_till: nil
            }
          ]
        )
      end
    end

    context 'and he has contract end' do
      let!(:contract_end) do
        create(:employee_event,
          event_type: 'contract_end', employee: employee, effective_at: 2.weeks.since)
      end

      it do
        expect(subject).to eq(
          [
            {
              effective_since: policies.first.effective_at,
              effective_till: 2.weeks.since.to_date
            }
          ]
        )
      end

      context 'and he was rehired' do
        let!(:hired) do
          create(:employee_event, event_type: 'hired', employee: employee, effective_at: hired_date)
        end
        let!(:new_etop) do
          create(:employee_time_off_policy,
            employee: employee, effective_at: hired_date,
            time_off_policy: create(:time_off_policy, time_off_category: category))
        end

        context 'more than day after contract end' do
          let(:hired_date) { 3.weeks.since }

          it do
            expect(subject).to eq(
              [
                {
                  effective_since: policies.first.effective_at,
                  effective_till: 2.weeks.since.to_date
                },
                {
                  effective_since: new_etop.effective_at,
                  effective_till: nil
                }
              ]
            )
          end
        end

        context 'one day after contract end' do
          let(:hired_date) { 2.weeks.since + 1.day }

          it do
            expect(subject).to eq(
              [
                {
                  effective_since: policies.first.effective_at,
                  effective_till: 2.weeks.since.to_date
                },
                {
                  effective_since: new_etop.effective_at,
                  effective_till: nil
                }
              ]
            )
          end

          context 'and there is next rehired and contract end' do
            let!(:new_contract_end) do
              create(:employee_event,
                event_type: 'contract_end', employee: employee, effective_at: 3.weeks.since)
            end
            let!(:new_hired) do
              create(:employee_event,
                event_type: 'hired', employee: employee, effective_at: 3.weeks.since + 1.day)
            end
            let!(:last_etop) do
              create(:employee_time_off_policy,
                employee: employee, effective_at: 3.weeks.since + 1.day,
                time_off_policy: create(:time_off_policy, time_off_category: category))
            end

            it do
              expect(subject).to eq(
                [
                  {
                    effective_since: policies.first.effective_at,
                    effective_till: 2.weeks.since.to_date
                  },
                  {
                    effective_since: new_etop.effective_at,
                    effective_till: 3.weeks.since.to_date
                  },
                  {
                    effective_since: last_etop.effective_at,
                    effective_till: nil
                  }
                ]
              )
            end
          end
        end
      end
    end
  end
end
