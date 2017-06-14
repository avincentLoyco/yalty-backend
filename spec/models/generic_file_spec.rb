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

  it 'accepts archive bigger than 20 MB' do
    archive = build(:generic_file,
      :with_zip,
      file_file_size: 66_666_666_666,
      fileable_type: 'Account'
    )
    expect(archive.valid?).to eq true
  end

  it 'does not accept not-archive files bigger than 20 MB' do
    archive = build(:generic_file, :with_jpg, file_file_size: 66_666_666_666)
    expect(archive.valid?).to eq false
    expect(archive.errors.messages[:file].first).to eq('must be less than 20 MB')
  end

  context 'processing' do
    let(:generic_file) { create(:generic_file, :with_jpg) }

    it { expect(generic_file.file_file_name).to eq("file_#{generic_file.id}.jpeg") }
    it { expect(generic_file.file.styles.keys).to include(:thumbnail) }
    it { expect(generic_file.sha_sums[:original_sha]).to_not be(nil) }
    it { expect(generic_file.sha_sums[:thumbnail_sha]).to_not be(nil) }
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

  context '#user_friendly_name' do
    let(:invoice) { create(:invoice, :with_file, date: Date.new(2016,1,1)) }
    let(:file_with_attr_version) { create(:generic_file, :with_jpg) }
    let!(:attr_version) do
      create(:employee_attribute, attribute_type: 'File',
        data: { size: 1000, file_type: 'jpg', file_sha: '123', id: file_with_attr_version.id })
    end
    let(:definition_name) { attr_version.attribute_definition.name }

    it { expect(invoice.generic_file.fileable_type).to eq('Invoice') }
    it { expect(invoice.generic_file.user_friendly_name).to eq('invoice-20160101.pdf') }
    it { expect(file_with_attr_version.fileable_type).to eq('EmployeeFile') }
    it { expect(file_with_attr_version.user_friendly_name).to eq("#{definition_name}.jpeg") }
  end
end
