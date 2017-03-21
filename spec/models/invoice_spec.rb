require 'rails_helper'

RSpec.describe Invoice, type: :model do
  it { is_expected.to have_db_column(:amount_due).of_type(:integer) }
  it { is_expected.to have_db_column(:status).of_type(:string) }
  it { is_expected.to have_db_column(:attempts).of_type(:integer) }
  it { is_expected.to have_db_column(:next_attempt).of_type(:datetime) }
  it { is_expected.to have_db_column(:date).of_type(:datetime) }
  it { is_expected.to have_db_column(:address) }
  it { is_expected.to have_db_column(:lines) }
  it { is_expected.to respond_to(:account) }

  it { is_expected.to validate_presence_of(:amount_due) }
  it { is_expected.to validate_presence_of(:status) }
  it { is_expected.to validate_presence_of(:date) }

  it { is_expected.to belong_to(:account) }
end
