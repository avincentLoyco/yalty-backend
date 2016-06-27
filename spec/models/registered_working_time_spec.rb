require 'rails_helper'

RSpec.describe RegisteredWorkingTime, type: :model do
  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:employee_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:date).of_type(:date) }
  it { is_expected.to have_db_column(:time_entries).of_type(:json).with_options(default: '{}') }
  it { is_expected.to have_db_column(:schedule_generated).of_type(:boolean).with_options(default: false) }

  it { is_expected.to have_db_index([:employee_id, :date]).unique }

  it { is_expected.to belong_to(:employee) }
end
