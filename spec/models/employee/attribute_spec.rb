require 'rails_helper'

RSpec.describe Employee::Attribute, type: :model do
  it { is_expected.to have_db_column(:name).with_options(null: false) }

  it { is_expected.to have_db_column(:type).with_options(null: false) }

  it { is_expected.to have_db_column(:data) }

  it { is_expected.to have_db_column(:employee_id) }
  it { is_expected.to have_db_index(:employee_id) }
  it { is_expected.to belong_to(:employee).inverse_of(:employee_attributes) }
end
