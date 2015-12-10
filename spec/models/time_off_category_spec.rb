require 'rails_helper'

RSpec.describe TimeOffCategory, type: :model do
  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:account_id).of_type(:uuid).with_options(null: false) }
  it { is_expected.to have_db_column(:name).of_type(:string).with_options(null: false) }
  it { is_expected.to have_db_column(:system).of_type(:boolean).with_options(null: false) }

  it { is_expected.to have_db_index(:account_id) }

  it { is_expected.to validate_presence_of(:account) }
  it { is_expected.to validate_presence_of(:name) }

  it { is_expected.to belong_to(:account) }

  it { expect(TimeOffCategory.new.system).to eq false }

  context 'editable scope' do
    let!(:editable_category) { create(:time_off_category) }
    let!(:system_category) { create(:time_off_category, :system) }

    it { expect(TimeOffCategory.all).to include(editable_category, system_category) }
    it { expect(TimeOffCategory.editable).to include(editable_category) }
    it { expect(TimeOffCategory.editable).to_not include(system_category) }
  end
end
