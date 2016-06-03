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

      context '.validity_date_for' do
        subject { RelatedPolicyPeriod.new(related_policy).validity_date_for(date) }
        let(:effective_at) { Date.today - 10.years }
        let(:date) { RelatedPolicyPeriod.new(related_policy).first_start_date  }
        let(:end_day) { 1 }
        let(:end_month) { 4 }

        context 'validity date in the same year' do
          context 'when years to effect equal nil' do
            let(:years_to_effect) { nil }

            it { expect(subject).to eq nil }
          end

          context 'when years to effect eqal 0' do
            let(:years_to_effect) { 0 }

            it { expect(subject).to eq '01/04/2006'.to_date }
          end

          context 'when years to effect equal 1 or more' do
            let(:years_to_effect) { 1 }

            it { expect(subject).to eq '01/04/2007'.to_date }
          end
        end

        context 'validity date in the next year' do
          let(:start_month) { 5 }

          context 'when years to effect equal nil' do
            let(:years_to_effect) { nil }

            it { expect(subject).to eq nil }
          end

          context 'when years to effect eqal 0' do
            let(:years_to_effect) { 0 }

            it { expect(subject).to eq '1/4/2007'.to_date }
          end

          context 'when years to effect equal 1 or more' do
            let(:years_to_effect) { 1 }

            it { expect(subject).to eq '1/4/2007'.to_date }
          end
        end

      end

      context 'effective_at later than start date' do
        let(:effective_at) { Date.today - 9.years - 8.months }
        let(:start_month) { 3 }

        it { expect(subject).to eq '01/03/2007'.to_date }
      end

      context 'effective_at in the future' do
        let(:effective_at) { Date.today + 6.months }

        it { expect(subject).to eq '01/01/2017'.to_date }
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
