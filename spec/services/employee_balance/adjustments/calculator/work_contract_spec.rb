require "rails_helper"

RSpec.describe Adjustments::Calculator::WorkContract do
  subject { described_class.call(current_allowance, previous_allowance, date) }

  let(:date)                             { Date.new(2017, 6, 26) } # 365 days in a year
  let(:previous_allowance)               { 9600 * 0.5 / 60.0 / 24.0 } # in days
  let(:current_allowance)                { 9600 * 0.8 / 60.0 / 24.0 }
  let(:number_of_days_until_end_of_year) { 189 }

  it do
    expect(subject).to eql((-previous_allowance + current_allowance) / 365.0 *
                            number_of_days_until_end_of_year)
  end
end
