require "rails_helper"

RSpec.describe Adjustments::Calculator::ContractEnd do
  subject { described_class.call(annual_allowance, date) }

  let(:date)             { Date.new(2017, 8, 1) }
  let(:annual_allowance) { 9600 * 0.5 / 60.0 / 24.0 } # in days

  let(:number_of_days_until_end_of_year) { 153 }

  # TODO: LOOK INTO ROUNDING PROBLEM (CAN FAIL ON TRAVIS)
  it do
    expect(subject).to eql((number_of_days_until_end_of_year * -annual_allowance / 365.0).round(15))
  end

  it { expect(subject).to eql(-1.397260273972603) }
end
