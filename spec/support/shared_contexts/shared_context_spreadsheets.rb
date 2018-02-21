RSpec.shared_context "shared_context_spreadsheets" do
  let(:folder_path)  { Rails.root.join("spec", "tmp", "spreadsheets#{ENV["TEST_ENV_NUMBER"]}") }
  let(:file_path)    { folder_path.join(file_name) }
  let(:fixture)      { Rails.root.join("spec", "fixtures", "files", fixture_name) }

  let!(:employees) do
    ["22222222-2222-2222-2222-222222222222", "33333333-3333-3333-3333-333333333333"].map do |id|
      create(:employee, id: id)
    end
  end

  let!(:account) do
    create(:account, id: "11111111-1111-1111-1111-111111111111", employees: employees)
  end

  before { FileUtils.mkdir_p(folder_path) }
  after  { FileUtils.rm_rf(folder_path) }
end
