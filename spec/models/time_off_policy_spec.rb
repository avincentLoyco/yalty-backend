require 'rails_helper'

RSpec.describe TimeOffPolicy, type: :model do
  it { is_expected.to have_db_column(:type).of_type(:string).with_options(null: false) }
  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:end_time).of_type(:date).with_options(null: false) }
  it { is_expected.to have_db_column(:start_time).of_type(:date).with_options(null: false) }
  it { is_expected.to have_db_column(:amount).of_type(:integer) }

  it { is_expected.to have_db_index(:time_off_category_id) }

  it { is_expected.to validate_presence_of(:type) }
  it { is_expected.to validate_presence_of(:end_time) }
  it { is_expected.to validate_presence_of(:start_time) }
  it { is_expected.to validate_presence_of(:time_off_category) }
  it { is_expected.to validate_inclusion_of(:type).in_array(%w(counter balance)) }
end
