require 'rails_helper'

RSpec.describe Employee::AttributeDefinition, type: :model do
  subject { build(:employee_attribute_definition) }

  it { is_expected.to have_db_column(:name) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:name).scoped_to(:account_id).case_insensitive }

  it { is_expected.to have_db_column(:label) }

  it { is_expected.to have_db_column(:system).with_options(default: false) }
  it { is_expected.to_not allow_value(nil).for(:system) }

  it { is_expected.to have_db_column(:attribute_type) }
  it { is_expected.to validate_presence_of(:attribute_type) }
  it 'should validate inclusion in list of defined attribute types' do
    allow(Attribute::Base).to receive(:attribute_types).and_return(['Fake', 'Test'])

    is_expected.to validate_inclusion_of(:attribute_type).in_array(['Fake', 'Test'])
  end

  it { is_expected.to have_db_column(:validation) }

  it { is_expected.to have_db_column(:multiple).with_options(default: false, null: false) }
  it { is_expected.to_not allow_value(nil).for(:multiple) }

  it { is_expected.to belong_to(:account).inverse_of(:employee_attribute_definitions) }
  it { is_expected.to validate_presence_of(:account) }
  it { is_expected.to have_db_column(:account_id).of_type(:uuid) }
end
