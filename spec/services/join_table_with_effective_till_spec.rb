require 'rails_helper'

RSpec.describe JoinTableWithEffectiveTill, type: :service do
  describe '#call' do
    context 'when join table is EmployeeTimeOffPolicy' do
      subject do
        described_class.new(EmployeeTimeOffPolicy, account_id)
          .call
          .sort_by { |etop_hash| etop_hash["effective_at"] }
      end

      context 'when there are etops' do
        let(:account_first)   { create(:account) }
        let(:employee_first)  { create(:employee, account: account_first) }
        let(:employee_second) { create(:employee, account: account_first) }
        let(:category_first)  { create(:time_off_category, account: account_first) }
        let(:category_second) { create(:time_off_category, account: account_first) }
        let(:policy_first)    { create(:time_off_policy, time_off_category: category_first) }
        let(:policy_second)   { create(:time_off_policy, time_off_category: category_second) }
        let(:account_id)      { account_first.id }
        let!(:etop_zero) do
          create(
            :employee_time_off_policy,
            employee: employee_first,
            time_off_policy: policy_second,
            effective_at: Time.now-1.days
          )
        end
        let!(:etop_second) do
          create(
            :employee_time_off_policy,
            employee: employee_second,
            time_off_policy: policy_second,
            effective_at: Time.now+1.days
          )
        end

        context 'when employees have multiple etops per category' do
          let!(:etop_first) do
            create(
              :employee_time_off_policy,
              employee: employee_first,
              time_off_policy: policy_first,
              effective_at: Time.now
            )
          end
          let!(:etop_third) do
            create(
              :employee_time_off_policy,
              employee: employee_first,
              time_off_policy: policy_second,
              effective_at: Time.now+3.days
            )
          end
          let!(:etop_fourth) do
            create(
              :employee_time_off_policy,
              employee: employee_first,
              time_off_policy: policy_first,
              effective_at: Time.now+4.days
            )
          end
          let!(:etop_fifth) do
            create(
              :employee_time_off_policy,
              employee: employee_second,
              time_off_policy: policy_second,
              effective_at: Time.now+5.days
            )
          end

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 6 }

          it { expect(subject[0]['effective_till']).to eq etop_third.effective_at.to_date.to_s }
          it { expect(subject[1]['effective_till']).to eq etop_fourth.effective_at.to_date.to_s }
          it { expect(subject[2]['effective_till']).to eq etop_fifth.effective_at.to_date.to_s }
          it { expect(subject[3]['effective_till']).to eq nil }
          it { expect(subject[4]['effective_till']).to eq nil }
          it { expect(subject[5]['effective_till']).to eq nil }
        end

        context 'when there are etops that are previous to te current in a category' do
          let!(:etop_previous) do
            create(
              :employee_time_off_policy,
              employee: employee_first,
              time_off_policy: policy_second,
              effective_at: Time.now-2.days
            )
          end

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 2 }

          it { expect(subject[0]['id']).to eq etop_zero.id }
          it { expect(subject[1]['id']).to eq etop_second.id }
          it { subject.map { |etop| expect(etop['id']).not_to eq etop_previous.id } }
        end

        context 'when there are employees with current etops but from other accounts' do
          let(:account_second)  { create(:account) }
          let(:employee_third)  { create(:employee, account: account_second) }
          let(:category_third)  { create(:time_off_category, account: account_second) }
          let(:policy_third)    { create(:time_off_policy, time_off_category: category_third) }
          let!(:etop_from_account_second) do
            create(
              :employee_time_off_policy,
              employee: employee_third,
              time_off_policy: policy_third,
              effective_at: Time.now+1.days
            )
          end

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 2 }

          it { expect(subject[0]['id']).to eq etop_zero.id }
          it { expect(subject[1]['id']).to eq etop_second.id }
          it { subject.map { |etop| expect(etop['id']).not_to eq etop_from_account_second.id } }
        end
      end

      context 'when employee has no policy in any category' do
        let(:account_id) { create(:employee).account_id }

        before { subject }

        it { expect(subject.class).to eq Array }
        it { expect(subject).to eq [] }
      end
    end
  end
end
