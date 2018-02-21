require "rails_helper"

RSpec.describe CompanyEvent, type: :model do
  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:title).of_type(:string).with_options(null: false) }
  it { is_expected.to have_db_column(:comment).of_type(:string) }
  it { is_expected.to have_db_column(:effective_at).of_type(:date) }
  it { is_expected.to have_db_column(:account_id).of_type(:uuid) }
  it { is_expected.to have_many(:files).class_name("GenericFile").dependent(:destroy) }
  it { is_expected.to validate_presence_of(:title) }
end
