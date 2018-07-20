require "rails_helper"
require "rake"

RSpec.describe "remove_original_files", type: :rake do
  include_context "rake"

  after { FileUtils.rm_rf(ENV["FILE_STORAGE_UPLOAD_PATH"]) }

  let(:env_subpath) { ENV["TEST_ENV_NUMBER"] || "1" }

  let(:file_path)     { ENV["FILE_STORAGE_UPLOAD_PATH"]}
  let(:original_path) { file_path + "/file_id_#{env_subpath}/original" }
  let(:second_path)   { file_path + "/file_id2_#{env_subpath}/original" }
  let(:file)          { original_path + "/file_file_id_#{env_subpath}.txt" }
  let(:original_file) { original_path + "/original.txt" }
  let(:second_file)   { second_path + "/file_file_id2_#{env_subpath}.txt" }

  context "with multiple folders and files" do
    before do
      FileUtils.mkdir_p(original_path)
      FileUtils.mkdir_p(second_path)

      FileUtils.touch(original_file)
      FileUtils.touch(file)
      FileUtils.touch(second_file)
      FileUtils.touch(second_path + "/original.txt")
      FileUtils.touch(second_path + "/impossible.txt")
    end

    it { expect { subject }.to change { Pathname(original_path).children.size }.to eq(1) }
    it { expect { subject }.to change { Pathname(second_path).children.size }.to eq(1) }

    context "leaves proper files" do
      before { subject }

      it { expect(Pathname(original_path).children).to eq([Pathname(file)]) }
      it { expect(Pathname(second_path).children).to eq([Pathname(second_file)]) }
      it { expect(Pathname(original_path).children).not_to include(Pathname(original_file)) }
    end
  end

  context "when orginal folder does not exist" do
    let(:not_original_path) { file_path + "/file_id_#{env_subpath}/not_original"}
    before do
      FileUtils.mkdir_p(not_original_path)
      FileUtils.touch(not_original_path + "/file.txt")
      FileUtils.touch(not_original_path + "/other_file.txt")
    end

    it { expect{ subject }.not_to change { Pathname(not_original_path).children.size } }
  end

  context "when original folder doesn't have file that is assigned" do
    before do
      FileUtils.mkdir_p(original_path)
      FileUtils.touch(original_file)
    end

    it { expect{ subject }.not_to change { Pathname(original_path).children.size } }

    context "does not delete files" do
      before { subject }
      it { expect(Pathname(original_path).children).to eq([Pathname(original_file)]) }
    end
  end
end
