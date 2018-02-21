require "rails_helper"

RSpec.describe Export::GenerateTimeOffSpreadsheet, type: :service do
  include_context "shared_context_spreadsheets"

  shared_examples "Valid CSV" do
    it { expect(File.exist?(file_path)).to be true }
    it { expect(FileUtils.compare_file(file_path, fixture)).to be true }
  end

  subject { described_class.new(account, folder_path).call }

  context "generates time_off csv file" do
    let(:file_name) { "time_offs.csv" }

    context "without time offs" do
      let(:fixture_name) { "empty_time_offs_test.csv" }

      before { subject }

      it_behaves_like "Valid CSV"
    end

    context "with time offs" do
      let(:fixture_name)      { "time_offs_test.csv" }

      let(:sickness_category) { account.time_off_categories.find_by(name: "sickness") }
      let(:accident_category) { account.time_off_categories.find_by(name: "accident") }
      let(:start_time)        { "2017-04-01 15:00:00".to_datetime }
      let(:end_time)          { "2017-04-03 03:00:00".to_datetime }
      let!(:sickness_time_off) do
        create(:time_off,
          employee: employees.first, time_off_category: sickness_category, start_time: start_time,
          end_time: end_time)
      end
      let!(:accident_time_off) do
        create(:time_off,
          employee: employees.second, time_off_category: accident_category, start_time: start_time,
          end_time: end_time)
      end

      before { subject }

      it_behaves_like "Valid CSV"
    end
  end
end
