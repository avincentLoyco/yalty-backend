require "rails_helper"

RSpec.describe Export::Employee::SpreadsheetDataBuilder, type: :service do
  subject { described_class.call(attributes, columns) }

  let(:attributes) { [first_employee_data, second_employee_data] }
  let(:columns) do
    {
      basic: basic_columns,
      plain: plain_columns,
      nested: nested_columns,
      nested_array: nested_array_columns,
    }
  end

  let(:first_employee_data) do
    instance_double(
      Export::Employee::Attributes,
      basic: first_basic_attributes,
      plain: first_plain_attributes,
      nested: first_nested_attributes,
      nested_array: first_nested_array_attributes
    )
  end

  let(:second_employee_data) do
    instance_double(
      Export::Employee::Attributes,
      basic: second_basic_attributes,
      plain: second_plain_attributes,
      nested: second_nested_attributes,
      nested_array: second_nested_array_attributes
    )
  end

  # first employee attributes
  let(:first_basic_attributes) { { employee_id: "1", hired_date: "2016-06-06" } }
  let(:first_plain_attributes) do
    {
      birthday: {
        value: "1993-06-06", effective_at: "2016-06-06"
      },
    }
  end

  let(:first_nested_attributes)       { {} }
  let(:first_nested_array_attributes) do
    [
      {
        value: {
          lastname: "Moriarty",
          firstname: "Son",
        },
        effective_at: "2015-06-06",
      },
    ]
  end

  # second employee attributes
  let(:second_basic_attributes) { { employee_id: "2", marital_status: "married" } }
  let(:second_plain_attributes) do
    {
      gender: {
        value: "male", effective_at: "2016-06-06"
      },
    }
  end
  let(:second_nested_attributes) do
    {
      spouse: {
        value: {
          lastname: "Adler",
          firstname: "Irene",
        },
        effective_at: "2012-06-06",
      },
    }
  end
  let(:second_nested_array_attributes) do
    [
      {
        value: {
          lastname: "Holmes",
          firstname: "Son",
        },
        effective_at: "2014-06-06",
      },
      {
        value: {
          lastname: "Holmes",
          firstname: "Daughter",
        },
        effective_at: "2015-06-06",
      },
    ]
  end

  # columns
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

  # results
  let(:result) { [first_employee_result, second_employee_result] }

  let(:first_employee_result) do
    [
      first_basic_result,
      first_plain_result,
      first_nested_result,
      first_nested_array_result,
    ]
  end

  let(:second_employee_result) do
    [
      second_basic_result,
      second_plain_result,
      second_nested_result,
      second_nested_array_result,
    ]
  end

  let(:first_basic_result)  { ["1", nil, nil, nil, nil, "2016-06-06", nil, nil] }
  let(:first_plain_result)  { [["1993-06-06", "2016-06-06"], [nil, nil]] }
  let(:first_nested_result) { [[[nil, nil], [nil, nil]]] }
  let(:first_nested_array_result) do
    [
      [["Moriarty", "2015-06-06"], ["Son", "2015-06-06"]],
      [[nil, nil], [nil, nil]],
    ]
  end

  let(:second_basic_result)  { ["2", nil, nil, nil, nil, nil, nil, "married"] }
  let(:second_plain_result)  { [[nil, nil], ["male", "2016-06-06"]] }
  let(:second_nested_result) { [[["Adler", "2012-06-06"], ["Irene", "2012-06-06"]]] }
  let(:second_nested_array_result) do
    [
      [["Holmes", "2014-06-06"], ["Son", "2014-06-06"]],
      [["Holmes", "2015-06-06"], ["Daughter", "2015-06-06"]],
    ]
  end

  # scenarios
  context "with two employees" do
    context "corresponding data between columns and attributes" do
      it { expect(subject).to eq(result) }
    end

    context "more attribute values than columns" do
      let(:plain_columns)       { [] }
      let(:first_plain_result)  { [] }
      let(:second_plain_result) { [] }

      it { expect(subject).to eq(result) }
    end
  end

  context "with one employee and more columns than attribute values" do
    let(:attributes) { [first_employee_data] }
    let(:result)     { [first_employee_result] }

    it { expect(subject).to eq(result) }
  end
end
