require 'rails_helper'
require 'rake'

RSpec.describe 'add_fileable_type_to_employee_files', type: :rake do
  include_context 'shared_context_account_helper'
  include_context 'rake'

  let!(:invoice) { create(:invoice, :with_file, date: Date.new(2016,1,1)) }
  let!(:file_with_attr_version) { create(:generic_file, :with_jpg) }
  let!(:attr_version) do
    create(:employee_attribute, attribute_type: 'File',
      data: { size: 1000, file_type: 'jpg', file_sha: '123', id: file_with_attr_version.id })
  end
  let!(:file_without_fileable_type) { create(:generic_file, :with_jpg, fileable_type: nil) }
  let!(:attr_version_2) do
    create(:employee_attribute, attribute_type: 'File',
      data: { size: 1000, file_type: 'jpg', file_sha: '123', id: file_without_fileable_type.id })
  end

  context 'add fileable_type to files with attribute versions' do
    it 'change fileable_type when it\'s nil' do
      expect { subject }
        .to change { file_without_fileable_type.reload.fileable_type }
        .from(nil)
        .to('EmployeeFile')
    end

    it { expect { subject }.to_not change { file_with_attr_version.reload.fileable_type }  }
    it { expect { subject }.to_not change { invoice.generic_file.reload.fileable_type }  }
  end
end
