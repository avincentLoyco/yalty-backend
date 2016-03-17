require 'rails_helper'

RSpec.describe WorkingPlaceTimeOffPolicy, type: :model do
  include_context 'shared_context_timecop_helper'

  let(:wptop) { create(:working_place_time_off_policy) }

  it { is_expected.to have_db_column(:working_place_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:time_off_policy_id).of_type(:uuid) }
  it { is_expected.to validate_presence_of(:working_place_id) }
  it { is_expected.to validate_presence_of(:time_off_policy_id) }
  it { is_expected.to validate_presence_of(:effective_at) }
  it { is_expected.to have_db_index([:time_off_policy_id, :working_place_id]) }
  it '' do
    is_expected.to have_db_index([:working_place_id, :time_off_policy_id, :effective_at]).unique
  end

  describe 'custom validations' do
    context '#effective_at_newer_than_previous_start_date' do
      let(:working_place_policy) { build(:working_place_time_off_policy, effective_at: effective_at) }
      let(:effective_at) { Time.now }
      subject { working_place_policy.valid? }

      context 'when employee does not have other policies' do
        it { expect(subject).to eq true }
        it { expect { subject }.to_not change { working_place_policy.errors.messages.count } }
      end

      context 'when employee does have other policies' do
        let(:category) { working_place_policy.time_off_policy.time_off_category }
        let(:old_policy) { create(:time_off_policy, time_off_category: category) }
        let!(:previous_working_place_policy) do
          create(:working_place_time_off_policy,
            working_place: working_place_policy.working_place, time_off_policy: old_policy
          )
        end

        context 'and new policy dates are valid' do
          it { expect(subject).to eq true }
          it { expect { subject }.to_not change { working_place_policy.errors.messages.count } }
        end

        context 'and new policy dates are invalid' do
          let(:effective_at) { '31.12.2014'.to_date }

          it { expect(subject).to eq false }

          it 'changes erros size' do
            expect { subject }.to change {
              working_place_policy.errors.messages.count }.by(1)
          end

          it 'adds proper error message' do
            subject

            expect(working_place_policy.errors.messages[:effective_at])
              .to include 'Must be after current policy previous perdiod start date'
          end
        end
      end
    end
  end
end
