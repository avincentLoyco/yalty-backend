require 'rails_helper'

RSpec.describe EmployeeWorkingPlace, type: :model do
  it { is_expected.to have_db_column(:employee_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:working_place_id).of_type(:uuid) }
  it { is_expected.to have_db_column(:effective_at).of_type(:date) }

  it { is_expected.to validate_presence_of(:employee) }
  it { is_expected.to validate_presence_of(:working_place) }
  it { is_expected.to validate_presence_of(:effective_at) }

  it { is_expected.to have_db_index([:working_place_id, :employee_id, :effective_at].uniq) }

  it { is_expected.to belong_to(:employee) }
  it { is_expected.to belong_to(:working_place) }
end
