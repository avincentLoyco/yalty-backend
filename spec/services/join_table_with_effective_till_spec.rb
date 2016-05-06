require 'rails_helper'

RSpec.describe JoinTableWithEffectiveTill, type: :service do
  describe '#call' do
    let(:policy_first)    { create(:time_off_policy, time_off_category: category_first) }
    let(:policy_second)   { create(:time_off_policy, time_off_category: category_second) }
    let(:employee)        { create(:employee) }
    let(:category_first)  { create(:time_off_category) }
    let(:category_second) { create(:time_off_category) }

    context 'when join table is EmployeeTimeOffPolicy' do
      subject do
        described_class.new(EmployeeTimeOffPolicy)
          .call
          .sort_by { |etop_hash| etop_hash["effective_at"] }
      end

      context 'and employee has diffrent policies with diffrent category' do
        let!(:etop_first) do
          create(
            :employee_time_off_policy,
            employee: employee,
            time_off_policy: policy_first,
            effective_at: Time.now
          )
        end
        let!(:etop_second) do
          create(
            :employee_time_off_policy,
            employee: employee,
            time_off_policy: policy_second,
            effective_at: Time.now+2.days
          )
        end
        let!(:etop_third) do
          create(
            :employee_time_off_policy,
            employee: employee,
            time_off_policy: policy_first,
            effective_at: Time.now+4.days
          )
        end
        let!(:etop_fourth) do
          create(
            :employee_time_off_policy,
            employee: employee,
            time_off_policy: policy_second,
            effective_at: Time.now+6.days
          )
        end
        let!(:etop_fifth) do
          create(
            :employee_time_off_policy,
            employee: employee,
            time_off_policy: policy_first,
            effective_at: Time.now+8.days
          )
        end

        before { subject }

        it { expect(subject.class).to eq Array }
        it { expect(subject.size).to eq 5 }

        it { expect(subject[0]['effective_till']).to eq etop_third.effective_at.to_date.to_s }
        it { expect(subject[1]['effective_till']).to eq etop_fourth.effective_at.to_date.to_s }
        it { expect(subject[2]['effective_till']).to eq etop_fifth.effective_at.to_date.to_s }
        it { expect(subject[3]['effective_till']).to eq nil }
        it { expect(subject[4]['effective_till']).to eq nil }
      end

      context 'and employee has two policies with diffrent category' do
        let!(:etop_first) do
          create(
            :employee_time_off_policy,
            employee: employee,
            time_off_policy: policy_first,
            effective_at: Time.now
          )
        end
        let!(:etop_second) do
          create(
            :employee_time_off_policy,
            employee: employee,
            time_off_policy: policy_second,
            effective_at: Time.now+2.days
          )
        end

        before { subject }

        it { expect(subject.class).to eq Array }
        it { expect(subject.size).to eq 2 }

        it { expect(subject[0]['effective_till']).to eq nil }
        it { expect(subject[1]['effective_till']).to eq nil }
      end

      context 'and policy has not category' do
        before { subject }

        it { expect(subject.class).to eq Array }
        it { expect(subject).to eq [] }
      end

      context 'and employee has not etops' do
        before { subject }

        it { expect(subject.class).to eq Array }
        it { expect(subject).to eq [] }
      end

      context 'and if etops effective_at is before now return only last etop in category' do
        let!(:etop_first) do
          create(
            :employee_time_off_policy,
            employee: employee,
            time_off_policy: policy_first,
            effective_at: Time.now-4.days
          )
        end
        let!(:etop_second) do
          create(
            :employee_time_off_policy,
            employee: employee,
            time_off_policy: policy_second,
            effective_at: Time.now-3.days
          )
        end
        let!(:etop_third) do
          create(
            :employee_time_off_policy,
            employee: employee,
            time_off_policy: policy_first,
            effective_at: Time.now-2.days
          )
        end
        let!(:etop_fourth) do
          create(
            :employee_time_off_policy,
            employee: employee,
            time_off_policy: policy_second,
            effective_at: Time.now-1.days
          )
        end

        before { subject }

        it { expect(subject.class).to eq Array }
        it { expect(subject.size).to eq 2 }

        it { expect(subject[0]['id']).to eq etop_third.id }
        it { expect(subject[1]['id']).to eq etop_fourth.id }
      end
    end
  end
end
