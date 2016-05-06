require 'rails_helper'

RSpec.describe WorkingPlace, type: :model do
  include_context 'shared_context_timecop_helper'

  it { is_expected.to have_db_column(:name) }

  it { is_expected.to have_many(:employees) }
  it { is_expected.to have_many(:employee_working_places) }
  it { is_expected.to respond_to(:employees) }

  it { is_expected.to have_db_column(:account_id).of_type(:uuid) }
  it { is_expected.to belong_to(:account).inverse_of(:working_places) }
  it { is_expected.to respond_to(:account) }
  it { is_expected.to validate_presence_of(:account) }
  it { is_expected.to belong_to(:holiday_policy) }
  it { is_expected.to belong_to(:presence_policy) }

  context '#previous_start_date' do
    let(:working_place) { create(:working_place) }
    subject { working_place.previous_start_date(active.time_off_policy.time_off_category_id) }

    context 'when only active policy exists' do
      let!(:active) { create(:working_place_time_off_policy, working_place: working_place) }
    end

    context 'when previous policy exists' do
      let(:policy) { create(:time_off_policy, years_to_effect: 3, start_day: 2) }
      let!(:previous) do
        create(:working_place_time_off_policy,
          working_place: working_place,
          effective_at: Time.now - 5.years,
          time_off_policy: policy
        )
      end

      let!(:active) do
        create(:working_place_time_off_policy,
          working_place: previous.working_place,
          effective_at: effective_at,
          time_off_policy: policy
        )
      end

      context 'and its last start date is after effective at' do
        let(:effective_at) { Time.now - 6.years }

        it { expect(subject).to eq '2/1/2013'.to_date }
      end

      context 'and its last start date is before effective at' do
        let(:effective_at) { Time.now - 2.years }

        it { expect(subject).to eq '2/1/2011'.to_date }
      end
    end
  end
end
