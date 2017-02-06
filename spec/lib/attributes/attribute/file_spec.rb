require 'rails_helper'

RSpec.describe Attribute::File do
  it { is_expected.to be_respond_to(:size) }
  it { is_expected.to be_respond_to(:id) }
  it { is_expected.to be_respond_to(:file_type) }
  it { is_expected.to be_respond_to(:original_sha) }
end
