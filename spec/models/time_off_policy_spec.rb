require 'rails_helper'

RSpec.describe TimeOffPolicy, type: :model do
  it { is_expected.to have_db_column(:policy_type).of_type(:string).with_options(null: false) }
  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:end_day).of_type(:integer).with_options(null: false) }
  it { is_expected.to have_db_column(:end_month).of_type(:integer).with_options(null: false) }
  it { is_expected.to have_db_column(:start_day).of_type(:integer).with_options(null: false) }
  it { is_expected.to have_db_column(:start_month).of_type(:integer).with_options(null: false) }
  it { is_expected.to have_db_column(:amount).of_type(:integer)
    .with_options(null: false, default: 0) }
  it { is_expected.to have_db_column(:years_to_effect).of_type(:integer)
    .with_options(null: false, default: 0) }

  it { is_expected.to have_db_index(:time_off_category_id) }

  it { is_expected.to validate_presence_of(:policy_type) }
  it { is_expected.to validate_presence_of(:end_day) }
  it { is_expected.to validate_presence_of(:end_month) }
  it { is_expected.to validate_presence_of(:start_day) }
  it { is_expected.to validate_presence_of(:start_month) }
  it { is_expected.to validate_presence_of(:time_off_category) }
  it { is_expected.to validate_inclusion_of(:policy_type).in_array(%w(counter balance)) }
  it { is_expected.to validate_numericality_of(:years_to_effect).is_greater_than_or_equal_to(0) }
end
