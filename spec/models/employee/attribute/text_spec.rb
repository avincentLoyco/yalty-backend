require 'rails_helper'

RSpec.describe Employee::Attribute::Text, type: :model do
  it { is_expected.to have_serialized_attribute(:text) }
end
