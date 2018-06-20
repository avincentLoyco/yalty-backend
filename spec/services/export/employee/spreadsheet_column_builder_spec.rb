require "rails_helper"

RSpec.describe Export::Employee::SpreadsheetColumnBuilder, type: :service do
  shared_examples "Valid Columns" do
    it { expect(subject[:basic]).to eq(basic_columns) }
    it { expect(subject[:plain]).to eq(plain_columns) }
    it { expect(subject[:nested]).to eq(nested_columns) }
    it { expect(subject[:nested_array]).to eq(nested_array_columns) }
  end

  subject { described_class.call(attributes) }

  let(:attributes) { [first_employee_data, second_employee_data] }

  let(:first_employee_data) do
    instance_double(
      Export::Employee::Attributes,
      plain: first_plain_attributes,
      nested: first_nested_attributes,
      nested_array: first_nested_array_attributes
    )
  end

  let(:second_employee_data) do
    instance_double(
      Export::Employee::Attributes,
      plain: second_plain_attributes,
      nested: second_nested_attributes,
      nested_array: second_nested_array_attributes
    )
  end

  let(:nested_attributes) do
    {
      value: {
        lastname: nil,
        firstname: nil,
      },
    }
  end

  # first employee attributes
  let(:first_plain_attributes)        { { birthday: {} } }
  let(:first_nested_attributes)       { {} }
  let(:first_nested_array_attributes) { [nested_attributes] }

  # second employee attributes
  let(:second_plain_attributes)        { { gender: {} } }
  let(:second_nested_attributes)       { { spouse: nested_attributes } }
  let(:second_nested_array_attributes) { [nested_attributes, nested_attributes] }

  # result columns
  let(:basic_columns) do
    [
      "employee_id",
      "lastname", "lastname (effective_at)",
      "firstname", "firstname (effective_at)",
      "hired_date", "contract_end_date",
      "martial_status"
    ]
  end

  let(:plain_columns) do
    [
      ["birthday", "birthday (effective_at)"],
      ["gender", "gender (effective_at)"],
    ]
  end

  let(:nested_columns) do
    {
      spouse: [
        ["spouse_lastname", "spouse_lastname (effective_at)"],
        ["spouse_firstname", "spouse_firstname (effective_at)"],
      ],
    }
  end

  let(:nested_array_columns) do
    {
      1 => [
        ["child_1_lastname", "child_1_lastname (effective_at)"],
        ["child_1_firstname", "child_1_firstname (effective_at)"],
      ],
      2 => [
        ["child_2_lastname", "child_2_lastname (effective_at)"],
        ["child_2_firstname", "child_2_firstname (effective_at)"],
      ],
    }
  end

  # scenarios
  context "with all attribute types present" do
    it_behaves_like "Valid Columns"
  end

  context "when neither employee has plain attributes" do
    let(:first_plain_attributes)  { {} }
    let(:second_plain_attributes) { {} }
    let(:plain_columns)           { [] }

    it_behaves_like "Valid Columns"
  end

  context "when neither employee has nested attributes" do
    let(:second_nested_attributes) { {} }
    let(:nested_columns)           { {} }

    it_behaves_like "Valid Columns"
  end

  context "when neither employee has nested array attributes" do
    let(:first_nested_array_attributes)  { {} }
    let(:second_nested_array_attributes) { {} }
    let(:nested_array_columns)           { {} }

    it_behaves_like "Valid Columns"
  end

  context "without attributes basic colums are still generated" do
    let(:first_plain_attributes)  { {} }
    let(:second_plain_attributes) { {} }
    let(:plain_columns)           { [] }

    let(:second_nested_attributes) { {} }
    let(:nested_columns)           { {} }

    let(:first_nested_array_attributes)  { {} }
    let(:second_nested_array_attributes) { {} }
    let(:nested_array_columns)           { {} }

    it_behaves_like "Valid Columns"
  end
end
