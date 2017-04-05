require 'rails_helper'

RSpec.describe RelatedPolicyPeriod do
  include_context 'shared_context_timecop_helper'

  shared_examples 'helper methods for related records' do
    let(:years_to_effect) { 2 }
    let(:effective_at) { Date.today }
    let(:start_month) { 1 }
    let(:end_month) { nil }
    let(:end_day) { nil }
    let(:time_off_policy) do
      build(:time_off_policy,
        years_to_effect: years_to_effect,
        start_month: start_month,
        end_month: end_month,
        end_day: end_day
      )
    end

    context '.policy_length' do
      subject { RelatedPolicyPeriod.new(related_policy).policy_length }

      context 'when years to effect greater than 1' do
        it { expect(subject).to eq 2 }
      end

      context 'when years to effect eq nil' do
        let(:years_to_effect) { nil }

        it { expect(subject).to eq 1 }
      end

      context 'when years to effect eq 0 or 1' do
        let(:years_to_effect) { 0 }

        it { expect(subject).to eq 1 }
      end
    end

    context '.previous_start_date' do
      let(:effective_at) { Date.today - 7.years }
      subject { RelatedPolicyPeriod.new(related_policy).previous_start_date }

      context 'policy length bigger than 1 year' do
        let(:years_to_effect) { 0 }

        it { expect(subject).to eq '01/01/2015'.to_date }
      end

      context 'policy length eql 1 year' do
        let(:years_to_effect) { 3 }

        it { expect(subject).to eq '01/01/2012'.to_date }
      end
    end

    context '.first_start_date' do
      subject { RelatedPolicyPeriod.new(related_policy).first_start_date }

      context 'effective_at in the past or today' do
        let(:effective_at) { Date.today - 10.years }

        context 'and the same date as start date' do
          it { expect(subject).to eq '01/01/2006'.to_date }
        end

        context 'and different date than start date' do
          let(:start_month) { 4 }

          it { expect(subject).to eq '01/04/2006'.to_date }
        end

        context 'when years to effect eq nil' do
          let(:years_to_effect) { nil }

          it { expect(subject).to eq '01/01/2006'.to_date }
        end
      end

      context '.validity_date_for_period_start' do
        subject { RelatedPolicyPeriod.new(related_policy).validity_date_for_period_start(date) }
        let(:effective_at) { Date.today - 10.years }
        let(:date) { RelatedPolicyPeriod.new(related_policy).first_start_date  }
        let(:end_day) { 1 }
        let(:end_month) { 4 }

        context 'validity date in the same year' do
          context 'when years to effect eqal 0' do
            let(:years_to_effect) { 0 }

            it { expect(subject).to eq(Time.zone.parse('02/04/2006 00:00:02')) }
          end

          context 'when years to effect equal 1 or more' do
            let(:years_to_effect) { 1 }

            it { expect(subject).to eq(Time.zone.parse('02/04/2007 00:00:02')) }
          end

          context 'when end date is the same day as start day' do
            let(:end_day) { 1 }
            let(:end_month) { 1 }

            context 'when years to effect eqal 0' do
              let(:years_to_effect) { 0 }

              it { expect(subject).to eq(Time.zone.parse('02/01/2006 00:00:02')) }
            end

            context 'when years to effect eqal 1' do
              let(:years_to_effect) { 1 }

              it { expect(subject).to eq(Time.zone.parse('02/01/2007 00:00:02')) }
            end
          end
        end

        context 'validity date in the next year' do
          let(:start_month) { 5 }

          context 'when years to effect eqal 0' do
            let(:years_to_effect) { 0 }

            it { expect(subject).to eq(Time.zone.parse('2/4/2007 00:00:02')) }
          end

          context 'when years to effect equal 1' do
            let(:years_to_effect) { 1 }

            it { expect(subject).to eq(Time.zone.parse('2/4/2008 00:00:02')) }
          end

          context 'when years to effect equal 2 or more' do
            let(:years_to_effect) { 2 }

            it { expect(subject).to eq(Time.zone.parse('2/4/2009 00:00:02')) }
          end

          context 'for day before start date' do
            let(:start_month) { 1 }
            let(:effective_at) { Date.new(2015, 12, 31) }

            context 'when years to effect eq 0' do
              let(:years_to_effect) { 0 }

              it { expect(subject).to eq(Time.zone.parse('2/4/2016 00:00:02')) }
            end

            context 'when years to effect eq 1' do
              let(:years_to_effect) { 1 }

              it { expect(subject).to eq(Time.zone.parse('2/4/2017 00:00:02')) }
            end

            context 'when years to effect eq 2' do
              let(:years_to_effect) { 2 }

              it { expect(subject).to eq(Time.zone.parse('2/4/2018 00:00:02')) }
            end
          end
        end
      end

      context '.validity_date_for_balance_at' do
        before { time_off_policy.update!(end_day: 1, end_month: 4) }

        subject do
          RelatedPolicyPeriod.new(related_policy).validity_date_for_balance_at(date, balance_type)
        end

        let(:balance_type) { 'addition' }
        let!(:related_policy) do
          create(:employee_time_off_policy, :with_employee_balance,
            time_off_policy: time_off_policy,
            effective_at: Time.zone.now
          )
        end

        shared_examples 'Contract end event in the future' do
          before do
            create(:employee_event,
              employee: related_policy.employee, event_type: 'contract_end',
              effective_at: contract_end_date)
          end

          context 'and it is before validity date' do
            let(:contract_end_date) { 4.months.since }

            it { expect(subject).to eq (Date.new(2016, 5, 2) + Employee::Balance::RESET_OFFSET) }
          end

          context 'and it is after validity date' do
            let(:contract_end_date) { Date.new(2018, 4, 2) }

            it { expect(subject).to eq (Date.new(2018, 4, 2) + Employee::Balance::REMOVAL_OFFSET) }
          end
        end

        context 'when balance is an addition' do
          let(:date) { Date.new(2016, 1, 1) }

          it { expect(subject).to eq (Date.new(2018, 4, 2) + Employee::Balance::REMOVAL_OFFSET) }

          it_behaves_like 'Contract end event in the future'
        end

        context 'when balance is an assignation' do
          let(:balance_type) { 'assignation' }
          let(:date) { related_policy.effective_at }

          context 'and it is assigned in policy start date' do
            it { expect(subject).to eq (Date.new(2018, 4, 2) + Employee::Balance::REMOVAL_OFFSET) }
          end

          context 'and it is not assigned in policy start date' do
            before { related_policy.update!(effective_at: 2.months.ago) }

            it { expect(subject).to eq (Date.new(2017, 4, 2) + Employee::Balance::REMOVAL_OFFSET) }
          end
        end

        context 'when balance type is time off or contract end' do
          let(:balance_type) { 'end_of_period' }
          let(:date) { related_policy.effective_at }

          context 'and there is previous addition' do
            before do
              related_policy.update!(effective_at: 2.months.ago)
              Employee::Balance.first.update!(
                effective_at: 2.months.ago,
                validity_date: Date.new(2017, 4, 2) + Employee::Balance::REMOVAL_OFFSET
              )
            end

            it { expect(subject).to eq (Date.new(2017, 4, 2) + Employee::Balance::REMOVAL_OFFSET) }
          end

          context 'and there is no previous addition' do
            it { expect(subject).to eq (Date.new(2017, 4, 2) + Employee::Balance::REMOVAL_OFFSET) }
          end
        end
      end
    end

    context '.last_start_date' do
      let(:effective_at) { Date.today - 7.years }
      subject { RelatedPolicyPeriod.new(related_policy).last_start_date }

      context 'years to effect eq nil' do
        let(:years_to_effect) { nil }

        it { expect(subject).to eq '01/01/2016'.to_date }
      end

      context 'years to effect eq 1' do
        let(:years_to_effect) { 0 }

        it { expect(subject).to eq '01/01/2016'.to_date }
      end

      context 'years to effect bigger than 1' do
        let(:years_to_effect) { 3 }

        it { expect(subject).to eq '01/01/2015'.to_date }
      end
    end

    context '.end_date' do
      subject { RelatedPolicyPeriod.new(related_policy).end_date }

      context 'when years to effect eq nil' do
        let(:years_to_effect) { nil }

        it { expect(subject).to eq '1/1/2017'.to_date }
      end

      context 'when years to effect eq 0' do
        let(:years_to_effect) { 0 }

        it { expect(subject).to eq '1/1/2017'.to_date }
      end

      context 'when years to effect eq 1' do
        let(:years_to_effect) { 1 }

        it { expect(subject).to eq '1/1/2017'.to_date }
      end

      context 'when years to effect eq 2 or more' do
        it { expect(subject).to eq '1/1/2018'.to_date }
      end
    end

    context '.last_validity_date' do
      subject { RelatedPolicyPeriod.new(related_policy).last_validity_date }

      context 'when time off policy has end dates' do
        let(:end_day) { 1 }
        let(:end_month) { 2 }

        it { expect(subject).to eq '1/2/2018'.to_date }
      end

      context 'when time off policy does not have end date' do
        it { expect(subject).to eq nil }
      end
    end
  end

  context 'for employee time off policy' do
    let(:related_policy) do
      build(:employee_time_off_policy,
        time_off_policy: time_off_policy,
        effective_at: effective_at
      )
    end

    it_behaves_like 'helper methods for related records'
  end
end
