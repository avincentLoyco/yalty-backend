require "rails_helper"

RSpec.describe Export::Employee::AttributesBuilder, type: :service do
  subject { described_class.call(employee, employee_attribute_versions, work_and_marriage_events) }

  shared_examples "Valid Attributes" do
    it { expect(subject.basic).to eq(basic_employee_attributes) }
    it { expect(subject.plain).to eq(plain_employee_attributes) }
    it { expect(subject.nested).to eq(nested_employee_attributes) }
    it { expect(subject.nested_array).to eq(nested_array_employee_attributes) }
  end

  before do
    allow(Export::Employee::MaritalStatus).to receive(:call).and_return(marital_status)
    allow(Export::Employee::ChildCounter).to receive(:call).and_return(children)
  end

  # call parameters
  let(:employee)                    { object_double(Employee.new, id: 1) }
  let(:employee_attribute_versions) { [string_attribute, nested_attribute, child_attribute] }
  let(:work_and_marriage_events)    { [] }

  # stubbed services responses
  let(:marital_status) do
    {
      status: "single",
      date: "2016-01-01",
    }
  end
  let(:children) do
    [
      {
        value: {
          lastname: "Holmes",
          firstname: "Son",
          birthdate: "1993-06-06",
          gender: "male",
          nationality: "English",
          is_student: "true",
        },
      },
    ]
  end

  # attributes passed in employee_attribute_versions
  let(:string_attribute) do
    {
      "data" => "{\"string\": \"Holmes\", \"attribute_type\": \"String\"}",
      "effective_at" => "2012-12-12",
      "event_type" => "hired",
      "name" => "lastname",
    }
  end

  let(:child_attribute) do
    {
      "data" => "{\"attribute_type\": \"Child\"}",
      "effective_at" => "2014-12-12",
      "event_type" => "child_birth",
      "name" => "child",
    }
  end

  let(:nested_attribute) do
    {
      "data" => "{
        \"firstname\": \"Irene\",
        \"lastname\": \"Adler\",
        \"attribute_type\": \"Person\"
      }",
      "effective_at" => "2013-12-12",
      "event_type" => "change",
      "name" => "spouse",
    }
  end

  # full results per attribute type
  let(:basic_employee_attributes) do
    {
      employee_id: employee.id,
      hired_date: hired_date,
      contract_end_date: contract_end_date,
    }
  end

  let(:plain_employee_attributes) do
    {
      lastname: { value: "Holmes", effective_at: "2012-12-12", event_type: "hired" },
      marital_status: { value: "single", effective_at: "2016-01-01", event_type: "single" },
    }
  end

  let(:nested_employee_attributes) do
    {
      spouse: {
        value: {
          lastname: "Adler",
          firstname: "Irene",
          birthdate: nil,
          gender: nil,
          nationality: nil,
          permit_type: nil,
          avs_number: nil,
          permit_expiry: nil,
        },
        effective_at: "2013-12-12",
        event_type: "change",
      },
    }
  end

  let(:nested_array_employee_attributes) { children }

  let(:hired_date) { nil }
  let(:contract_end_date) { nil }

  # scenarios
  context "with all types of attributes" do
    it_behaves_like "Valid Attributes"
  end

  context "with only String attribute" do
    let(:employee_attribute_versions)      { [string_attribute] }
    let(:nested_employee_attributes)       { {} }
    let(:nested_array_employee_attributes) { [] }

    it_behaves_like "Valid Attributes"
  end

  context "with Child attribute" do
    let(:employee_attribute_versions) { [child_attribute] }
    let(:nested_employee_attributes)  { {} }
    let(:plain_employee_attributes) do
      { marital_status: { value: "single", effective_at: "2016-01-01", event_type: "single" } }
    end

    it_behaves_like "Valid Attributes"
  end

  context "with nested attribute" do
    let(:employee_attribute_versions)      { [nested_attribute] }
    let(:nested_array_employee_attributes) { [] }
    let(:plain_employee_attributes) do
      { marital_status: { value: "single", effective_at: "2016-01-01", event_type: "single" } }
    end

    it_behaves_like "Valid Attributes"
  end

  context "with hired and contract end events" do
    let(:work_and_marriage_events) do
      [
        { "event_type" => "hired", "effective_at" => "2011-06-06" },
        { "event_type" => "contract_end", "effective_at" => "2017-06-06" },
      ]
    end
    let(:hired_date) { "2011-06-06" }
    let(:contract_end_date) { "2017-06-06" }

    it_behaves_like "Valid Attributes"
  end
end
