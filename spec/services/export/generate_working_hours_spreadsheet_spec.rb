require "rails_helper"

RSpec.describe Export::GenerateWorkingHoursSpreadsheet, type: :service do
  include_context "shared_context_spreadsheets"

  shared_examples "Valid CSV" do
    it { expect(File.exist?(file_path)).to be true }
    it { expect(FileUtils.compare_file(file_path, fixture)).to be true }
  end

  subject { described_class.new(account, folder_path).call }

  context "generates working_hours csv file" do
    let(:file_name) { "working_hours.csv" }

    context "with no registered working times" do
      let(:spec_name) { "without_registered" }
      let(:fixture_name) { "empty_working_hours_test.csv" }
      before { subject }

      it_behaves_like "Valid CSV"
    end

    context "with registered working time" do
      let(:spec_name) { "with_registered" }
      let(:fixture_name) { "working_hours_test.csv" }

      before do
        create(:registered_working_time, employee: employees.first)
        create(:registered_working_time,
          date: "6/6/2016", comment: "asd", employee: employees.second)
        subject
      end

      it_behaves_like "Valid CSV"
    end

    context "with registered working time that has more time entries" do
      let(:fixture_name)  { "working_hours_test2.csv" }

      let!(:working_time) { create(:registered_working_time, employee: employees.first) }
      let!(:second_working_time) do
        create(:registered_working_time,
          date: "6/6/2016", comment: "asd", employee: employees.second,
          time_entries: [{ start_time: "8:00:00", end_time: "10:00:00" }])
      end

      before { subject }

      it_behaves_like "Valid CSV"
    end
  end
end
