require "rails_helper"

RSpec.describe Adjustments::Calculator::Hired do
  subject { described_class.call(annual_allowance, date) }

  let(:date)                             { Date.new(2017, 6, 26) } # 365 days in a year
  let(:annual_allowance)                 { 9600 * 0.5 / 60.0 / 24.0 } # in days
  let(:number_of_days_until_end_of_year) { 189 }

  it { expect(subject).to eql(annual_allowance / 365.0 * number_of_days_until_end_of_year) }
end
