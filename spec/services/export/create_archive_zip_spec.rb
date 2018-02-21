require "rails_helper"

RSpec.describe Export::CreateArchiveZip do
  let(:account) { create(:account) }
  let(:employee) { create(:employee, account: account) }
  let(:file_with_attr_version) { create(:generic_file) }
  let(:attr_version) do
    create(:employee_attribute, attribute_type: "File", employee: employee,
      data: { size: 1000, file_type: "jpg", file_sha: "123", id: file_with_attr_version.id })
  end

  subject(:create_archive) { described_class.new(account).call }

  context "when there is no archive yet" do
    it { expect { create_archive }.to change { GenericFile.count }.by(1) }
    it { expect { create_archive }.to change { account.archive_file }.from(nil) }

    context "file is zip" do
      before { create_archive }

      it { expect(account.archive_file.file_content_type).to eq("application/zip") }
    end
  end

  context "when there already is an archive file" do
    let!(:old_archive) { create(:generic_file, :with_zip) }
    let!(:account) { create(:account, archive_file: old_archive) }

    it { expect { create_archive }.to change { GenericFile.count }.by(1) }
    it { expect { create_archive }.to change { old_archive.fileable_id }.from(account.id).to(nil) }
    it { expect { create_archive }.to change { account.archive_file }.from(old_archive) }
  end
end
