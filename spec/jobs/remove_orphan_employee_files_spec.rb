require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe RemoveOrphanEmployeeFiles do
  describe 'queue' do
    it 'puts a job on proper queue' do
      expect { described_class.perform_later }
        .to change(Sidekiq::Queues['employee_files'], :size).by(1)
    end
  end

  describe '#perform' do
    let(:employee) { create(:employee) }
    let(:employee_files) { create_list(:employee_file, 2, :with_jpg) }
    let(:orphan_file) { create(:employee_file, :without_file) }
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

    let(:existing_dirs) do
      employee_files.map { |f| "#{Dir.pwd}/#{ENV['FILE_STORAGE_UPLOAD_PATH']}/#{f.id}" }
    end
    let(:removed_dir) { "#{Dir.pwd}/#{ENV['FILE_STORAGE_UPLOAD_PATH']}/#{orphan_file.id}" }

    let(:dir_path) { "#{Dir.pwd}/#{ENV['FILE_STORAGE_UPLOAD_PATH']}/#{orphan_file.id}/original" }
    let(:destination_path) { "#{dir_path}/test.jpg" }
    subject(:create_orphan_file) do
      FileUtils.mkdir_p(dir_path)
      FileUtils.cp(File.join(Dir.pwd, '/spec/fixtures/files/test.jpg'), destination_path)
    end

    before do
      create_orphan_file
      Timecop.freeze(2.days.from_now)
      described_class.new.perform
    end

    after { Timecop.return }

    it { expect(Dir.exist?(existing_dirs.first)).to be(true) }
    it { expect(Dir.exist?(existing_dirs.second)).to be(true) }
    it { expect(Dir.exist?(removed_dir)).to be(false) }
  end
end
