require 'rails_helper'
require 'employee/attribute'

RSpec.describe Employee::Attribute, type: :model do
  it { is_expected.to have_db_column(:attribute_name) }
  it { is_expected.to have_db_column(:attribute_type) }
  it { is_expected.to have_db_column(:data) }
  it { is_expected.to have_db_column(:effective_at) }

  it { is_expected.to have_db_column(:employee_id) }
  it { is_expected.to belong_to(:employee).inverse_of(:employee_attributes) }

  it { is_expected.to have_one(:account).through(:employee) }

  it { is_expected.to belong_to(:attribute_definition).class_name('Employee::AttributeDefinition') }

  it { is_expected.to belong_to(:event).class_name('Employee::Event') }
end
