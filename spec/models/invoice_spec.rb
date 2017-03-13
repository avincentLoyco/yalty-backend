require 'rails_helper'

RSpec.describe Invoice, type: :model do
  it { is_expected.to have_db_column(:total_payed_amount).of_type(:integer) }
  it { is_expected.to have_db_column(:status).of_type(:string) }
  it { is_expected.to have_db_column(:attempts).of_type(:integer) }
  it { is_expected.to have_db_column(:next_attempt).of_type(:date) }
  it { is_expected.to have_db_column(:date).of_type(:date) }
  it { is_expected.to have_db_column(:address) }
  it { is_expected.to have_db_column(:invoice_items) }
  it { is_expected.to respond_to(:account) }

  it { is_expected.to validate_presence_of(:total_payed_amount) }
  it { is_expected.to validate_presence_of(:status) }
  it { is_expected.to validate_presence_of(:date) }

  it { is_expected.to belong_to(:account) }
end
