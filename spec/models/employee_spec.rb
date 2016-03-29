require 'rails_helper'

RSpec.describe Employee, type: :model do
  it { is_expected.to have_db_column(:account_id).of_type(:uuid) }
  it { is_expected.to belong_to(:account).inverse_of(:employees) }
  it { is_expected.to respond_to(:account) }
  it { is_expected.to validate_presence_of(:account) }

  it { is_expected.to belong_to(:working_place) }

  it { is_expected.to have_many(:employee_attribute_versions).inverse_of(:employee) }
  it { is_expected.to have_many(:time_offs) }
  it { is_expected.to have_many(:employee_balances) }

  it { is_expected.to have_many(:employee_attributes).inverse_of(:employee) }

  it { is_expected.to have_many(:events).inverse_of(:employee) }
  it { is_expected.to belong_to(:presence_policy) }
  it { is_expected.to belong_to(:holiday_policy) }

  context 'related time offs helpers' do
    include_context 'shared_context_timecop_helper'

    let(:account) { create(:account) }
    let(:category) { create(:time_off_category, account: account) }
    let(:policy) { create(:time_off_policy, time_off_category: category, start_month: 4) }
    let(:previous_policy) { create(:time_off_policy, time_off_category: category) }
    let(:employee) { create(:employee, account: account) }

    context 'when previous policy not present' do
      let!(:current_policy) do
        create(:employee_time_off_policy,
          employee: employee, time_off_policy: previous_policy, effective_at: effective_at
        )
      end

      context 'when employee does not have previous policy' do
        let(:effective_at) { Date.today - 2.years }

        it { expect(employee.current_start_date(category.id)).to eq '1/1/2016'.to_date }
        it { expect(employee.current_end_date(category.id)).to eq '1/1/2017'.to_date }
        it { expect(employee.previous_start_date(category.id)).to eq '1/1/2015'.to_date }
        it { expect(employee.previous_policy_period(category.id))
          .to include(('1.1.2015'.to_date)..('1.1.2016'.to_date)) }
        it { expect(employee.current_policy_period(category.id))
          .to include(('1.1.2016'.to_date)..('1.1.2017'.to_date)) }
      end
    end

    context 'when previous policy present' do
      let(:second_effective_at) { Date.today - 2.years }
      let!(:second_policy) do
        create(:employee_time_off_policy,
          employee: employee, time_off_policy: policy, effective_at: second_effective_at
        )
      end
      let!(:current_policy) do
        create(:employee_time_off_policy,
          employee: employee, time_off_policy: previous_policy, effective_at: effective_at
        )
      end

      context '#current_start_date' do
        subject { employee.current_start_date(category.id) }

        context 'but already new came in' do
          let(:effective_at) { Date.today - 4.months }

          it { expect(subject).to eq '1/1/2016'.to_date }
        end

        context 'and new has start date in future' do
          let(:effective_at) { Date.today + 1.month }

          it { expect(subject).to eq '1/4/2015'.to_date }
        end
      end

      context '#current_end_date' do
        subject { employee.current_end_date(category.id) }

        context 'when there is new policy in the future' do
          let(:effective_at) { Date.today + 2.months }

          it { expect(subject).to eq '1/4/2016'.to_date }
        end

        context 'when policy after current policy end date' do
          before { policy.update!(years_to_effect: 8) }
          let(:effective_at) { Date.today + 1.year }

          it { expect(subject).to eq '1/1/2017'.to_date }
        end
      end

      context '#current_policy_period' do
        subject { employee.current_policy_period(category.id) }

        context 'other policy end date' do
          let(:effective_at) { Date.today + 1.month }

          it { expect(employee.current_policy_period(category.id))
            .to include(('1.1.2016'.to_date)..('1.4.2016'.to_date)) }
        end
      end

      context '#previous_start_date' do
        subject { employee.previous_start_date(category.id) }

        context 'other policy period' do
          let(:effective_at) { Date.today - 4.months }

          it { expect(subject).to eq '1/4/2015'.to_date }
        end
      end

      context '#previous_policy_period' do
        subject { employee.previous_start_date(category.id) }

        context 'other policy period' do
          let(:effective_at) { Date.today - 1.year }

          it { expect(employee.current_policy_period(category.id))
            .to include(('1.4.2015'.to_date)..('1.1.2016'.to_date)) }
        end
      end
    end
  end
end
