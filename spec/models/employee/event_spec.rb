require 'rails_helper'

RSpec.describe Employee::Event, type: :model do
  subject! { FactoryGirl.build(:employee_event) }

  it { is_expected.to have_db_column(:employee_id) }
  it { is_expected.to have_db_index(:employee_id) }
  it { is_expected.to belong_to(:employee).inverse_of(:events) }
  it { is_expected.to validate_presence_of(:employee) }

  it { is_expected.to have_one(:account).through(:employee) }

  it { is_expected.to have_db_column(:effective_at) }
  it { is_expected.to validate_presence_of(:effective_at) }

  it { is_expected.to have_db_column(:comment) }
end
