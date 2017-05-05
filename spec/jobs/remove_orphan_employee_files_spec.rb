require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe RemoveOrphanEmployeeFiles, type: :job do
  describe 'queue' do
    it 'puts a job on proper queue' do
      expect { described_class.perform_later }
        .to have_enqueued_job(RemoveOrphanEmployeeFiles).exactly(1)
    end
  end

  describe '#perform' do
    let(:created_at) { 7.days.ago }
    let(:employee) { create(:employee) }
    let!(:employee_files) { create_list(:employee_file, 2, :with_jpg, created_at: created_at) }
    let(:orphan_file) { create(:employee_file, :without_file, created_at: created_at) }
    let!(:employee_attributes) do
      employee_files.each do |file|
        create(:employee_attribute, employee: employee, attribute_type: 'File', data: {
          id: file.id,
          size: file.file_file_size,
          file_type: file.file_content_type,
          file_sha: '123'
        })
      end
    end

    let(:removed_dir) { Rails.application.config.file_upload_root_path.join(orphan_file.id) }
    let(:dir_path) do
      Rails.application.config.file_upload_root_path.join(orphan_file.id, 'original')
    end
    let(:destination_path) { "#{dir_path}/test.jpg" }
    subject(:create_orphan_file) do
      FileUtils.mkdir_p(dir_path)
      FileUtils.cp(File.join(Dir.pwd, '/spec/fixtures/files/test.jpg'), destination_path)
    end

    before do
      create_orphan_file
      described_class.new.perform
    end

    it { expect(Dir.exist?(removed_dir)).to be(false) }
    it { expect(EmployeeFile.count).to eq(2) }
  end
end
