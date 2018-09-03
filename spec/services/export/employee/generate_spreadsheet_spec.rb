require "rails_helper"

RSpec.describe Export::Employee::GenerateSpreadsheet, type: :service do
  include_context "shared_context_spreadsheets"

  shared_examples "Valid CSV" do
    before { subject }
    it { expect(File.exist?(file_path)).to be true }
    it { expect(FileUtils.compare_file(file_path, fixture)).to be true }
  end

  subject { described_class.call(employee.account, folder_path) }

  let(:file_name) { "employees.csv" }

  # Attribute Definitions
  let(:spouse_definition) do
    create(
      :employee_attribute_definition,
      :system,
      account: employee.account,
      name: "spouse",
      attribute_type: Attribute::Person.attribute_type
    )
  end

  let(:child_definition) do
    create(
      :employee_attribute_definition,
      :system,
      account: employee.account,
      name: "child",
      attribute_type: Attribute::Child.attribute_type
    )
  end

  # Employee Events
  let(:employee) do
    create(
      :employee,
      :with_attributes,
      id: "44444444-4444-4444-4444-444444444444",
      hired_at: "06-06-2012",
      contract_end_at: "06-06-2016",
      employee_attributes: basic_employee_attributes
    )
  end

  let(:change_event) do
    create(
      :employee_event,
      effective_at: "06-06-2015".to_date,
      event_type: "change",
      employee: employee
    )
  end

  # Basic Attribute Versions
  let(:basic_employee_attributes) do
    {
      firstname: "Sherlock",
      lastname: "Holmes",
      birthday: "1887-01-01",
      gender: "Male",
      job_title: "Detective",
    }
  end

  context "with basic attributes" do
    let(:fixture_name) { "employee_basic_attributes.csv" }

    it_behaves_like "Valid CSV"
  end

  context "with nested attribute" do
    let(:fixture_name) { "employee_nested_attributes.csv" }
    let!(:wife) do
      create(
        :employee_attribute,
        employee: employee,
        event: change_event,
        attribute_definition: spouse_definition,
        value: { lastname:      "Adler",              firstname:   "Irene",
                 birthdate:     "06-06-1993".to_date, gender:      "female",
                 nationality:   "English",            permit_type: "permit",
                 permit_expiry: "06-06-2000".to_date, avs_number:  "avs" }
      )
    end

    it_behaves_like "Valid CSV"
  end

  context "with child attributes" do
    let(:child_birth_event) do
      create(
        :employee_event,
        effective_at: "09-09-2015".to_date,
        event_type: "child_birth",
        employee: employee
      )
    end

    let!(:first_child) do
      create(
        :employee_attribute,
        employee: employee,
        event: child_birth_event,
        attribute_definition: child_definition,
        value: { lastname:    "Holmes",             firstname:   "Son",
                 birthdate:   "06-06-1993".to_date, gender:      "male",
                 nationality: "English",            is_student:  true }
      )
    end

    context "with single child" do
      let(:fixture_name) { "employee_single_child.csv" }

      it_behaves_like "Valid CSV"
    end

    context "with two children" do
      let(:fixture_name) { "employee_two_children.csv" }
      let(:second_child_birth_event) do
        create(
          :employee_event,
          effective_at: "12-09-2015".to_date,
          event_type: "child_birth",
          employee: employee
        )
      end

      let!(:second_child) do
        create(
          :employee_attribute,
          employee: employee,
          event: second_child_birth_event,
          attribute_definition: child_definition,
          value: { lastname:    "Holmes",             firstname:   "Daughter",
                   birthdate:   "06-06-1996".to_date, gender:      "female",
                   nationality: "English",            is_student:  true }
        )
      end

      it_behaves_like "Valid CSV"
    end

    context "with single child that died" do
      let(:fixture_name) { "employee_basic_attributes.csv" }
      let(:child_death_event) do
        create(
          :employee_event,
          effective_at: "12-10-2015".to_date,
          event_type: "child_death",
          employee: employee
        )
      end

      let!(:first_child_death) do
        create(
          :employee_attribute,
          employee: employee,
          event: child_death_event,
          attribute_definition: child_definition,
          value: { lastname:    "Holmes",             firstname:  "Son",
                   birthdate:   "06-06-1993".to_date, gender:     "male",
                   nationality: "English",            is_student: true }
        )
      end

      it_behaves_like "Valid CSV"
    end
  end
end
