require 'rails_helper'

RSpec.describe GenericFile, type: :model do
  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_attached_file(:file) }
  it { is_expected.to validate_attachment_size(:file).less_than(20.megabytes) }
  it { is_expected.to belong_to(:fileable) }

  context 'format validations' do
    it 'accepts jpg' do
      generic_file = build(:generic_file, :with_jpg)

      expect(generic_file.valid?).to eq true
    end

    it 'accepts pdf' do
      generic_file = build(:generic_file, :with_pdf)

      expect(generic_file.valid?).to eq true
    end

    it 'accepts doc' do
      generic_file = build(:generic_file, :with_doc)

      expect(generic_file.valid?).to eq true
    end

    it 'accepts docx' do
      generic_file = build(:generic_file, :with_docx)

      expect(generic_file.valid?).to eq true
    end
  end

  context 'processing' do
    let(:generic_file) { create(:generic_file, :with_jpg) }

    it { expect(generic_file.file_file_name).to eq("file_#{generic_file.id}.jpg") }
    it { expect(generic_file.file.styles.keys).to include(:thumbnail) }
  end

  context 'scopes' do
    context '.orphans' do
      let(:orphan_file) { create(:generic_file) }
      let(:invoice) { create(:invoice) }
      let(:file_with_invoice) { create(:generic_file, fileable: invoice) }
      let(:file_with_attr_version) { create(:generic_file) }
      let(:attr_version) do
        create(:employee_attribute, attribute_type: 'File',
          data: { size: 1000, file_type: 'jpg', file_sha: '123', id: file_with_attr_version.id })
      end

      it { expect(GenericFile.orphans).to match_array([orphan_file]) }
    end
  end
end
