require 'rails_helper'

RSpec.describe EmployeeFile, type: :model do
  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_attached_file(:file) }
  it { is_expected.to validate_attachment_size(:file).less_than(20.megabytes) }

  context 'format validations' do
    it 'accepts jpg' do
      employee_file = build(:employee_file, :with_jpg)

      expect(employee_file.valid?).to eq true
    end

    it 'accepts pdf' do
      employee_file = build(:employee_file, :with_pdf)

      expect(employee_file.valid?).to eq true
    end

    it 'accepts doc' do
      employee_file = build(:employee_file, :with_doc)

      expect(employee_file.valid?).to eq true
    end

    it 'accepts docx' do
      employee_file = build(:employee_file, :with_docx)

      expect(employee_file.valid?).to eq true
    end
  end
end
