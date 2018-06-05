require "rails_helper"

RSpec.describe Export::GenerateEmployeesJournal, type: :service do
  include_context "shared_context_timecop_helper"

  shared_examples "Valid CSV" do
    it { expect(File.exist?(file_path)).to be true }
    it { expect(FileUtils.compare_file(file_path, fixture)).to be true }
  end

  let(:folder_path) { Rails.application.config.file_upload_root_path }
  let(:file_path) { folder_path.join(file_name) }
  let(:fixture) { Rails.root.join("spec", "fixtures", "files",  fixture_name) }
  let(:file_name) { "#{account.id}-#{journal_timestamp.strftime("%Y-%m-%dT%H:%M:%S")}.csv" }
  let(:last_employee_journal_export) { nil }
  let(:journal_timestamp) { Time.zone.parse("2016-03-01") }

  let!(:account) do
    create(:account, id: "11111111-1111-1111-1111-111111111111",
      last_employee_journal_export: last_employee_journal_export)
  end

  let(:fname_definition) { account.employee_attribute_definitions.find_by(name: "firstname") }
  let(:lname_definition) { account.employee_attribute_definitions.find_by(name: "lastname") }

  let(:address_definition) do
    create(:employee_attribute_definition, name: "address", account: account,
      attribute_type: Attribute::Address.attribute_type)
  end

  let(:employees_ids) do
    ["22222222-2222-2222-2222-222222222222", "33333333-3333-3333-3333-333333333333"]
  end

  let(:events_ids) do
    ["44444444-4444-4444-4444-444444444444", "55555555-5555-5555-5555-555555555555"]
  end

  let!(:employees) do
    employees_ids.map.with_index do |id, index|
      create(:employee, id: id, account: account, events: [events[index]])
    end
  end

  let(:events) { events_ids.map { |id| build(:employee_event, id: id, event_type: "hired") } }

  let!(:fname_attributes) do
    employees_ids.map.with_index do |id, index|
      build(:employee_attribute, employee: employees[index], event: events[index], account: account,
        attribute_definition: fname_definition, value: "Mirek", updated_at: 15.days.ago)
    end
  end

  let!(:lname_attributes) do
    employees_ids.map.with_index do |id, index|
      build(:employee_attribute, employee: employees[index], event: events[index], account: account,
        attribute_definition: lname_definition, value: "Swirek", updated_at: 10.days.ago)
    end
  end

  let!(:moving_event) do
    create(:employee_event, id: "77777777-7777-7777-7777-777777777777", event_type: "moving",
      employee: employees.first)
  end

  let(:address_data) do
    {
      city: "London",
      country: "England",
      postalcode: "NW1",
      region: "Westminster",
      street: "Baker Street",
      streetno: "221B",
    }
  end

  let(:moving_attribute) do
    build(:employee_attribute, employee: employees.first, event: moving_event, account: account,
      attribute_definition: address_definition, data: ::Attribute::Address.new(address_data),
      updated_at: 5.days.ago)
  end

  subject(:create_csv) do
    described_class.new(account, account.last_employee_journal_export, journal_timestamp, folder_path).call
  end

  before do
    FileUtils.mkdir_p(folder_path)
    events.each_with_index do |event, index|
      event.employee_attribute_versions << [fname_attributes[index], lname_attributes[index]]
    end
    moving_event.employee_attribute_versions << moving_attribute
  end

  after { FileUtils.rm_rf(folder_path) }

  context "first export" do
    let(:fixture_name) { "employees_journal_first_test.csv" }

    before { create_csv }

    it_behaves_like "Valid CSV"
  end

  context "scheduled export" do
    let(:fixture_name) { "employees_journal_scheduled_test.csv" }
    let(:last_employee_journal_export) { Time.zone.parse("2016-02-01") }

    let!(:marriage_event) do
      create(:employee_event, id: "66666666-6666-6666-6666-666666666666", event_type: "marriage",
        updated_at: Time.zone.parse("2016-02-15"), employee: employees.first,
        effective_at: Time.zone.parse("2016-01-01"))
    end

    let(:marriage_attribute) do
      build(:employee_attribute, employee: employees.first, event: marriage_event, account: account,
        attribute_definition: lname_definition, value: "Motylek")
    end

    before do
      marriage_event.employee_attribute_versions << marriage_attribute
      create_csv
    end

    it_behaves_like "Valid CSV"
  end

  context "empty export" do
    let(:fixture_name) { "employees_journal_first_test.csv" }

    before do
      account.update!(last_employee_journal_export: journal_timestamp)
      create_csv
    end

    it { expect(File.exist?(file_path)).to be false }
  end
end
