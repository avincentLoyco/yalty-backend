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

  context 'uniqueness validation' do
    let(:category) { build(:time_off_category) }
    let(:duplicate_category) { category.dup }

    before { category.save }

    context 'with the same account' do
      it { expect(duplicate_category.valid?).to eq false }
      it { expect { duplicate_category.valid? }
        .to change { duplicate_category.errors.messages.count }.by(1) }
    end

    context 'with other accounts' do
      let(:same_name_category) { build(:time_off_category, name: category.name) }

      it { expect(same_name_category.valid?).to eq true }
      it { expect { same_name_category.valid? }
        .to_not change { same_name_category.errors.messages } }
    end
  end
end
