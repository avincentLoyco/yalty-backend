module Adjustments
  module Calculator
    class ContractEnd
      include Calendar

      attr_reader :previous_allowance, :days_in_a_year, :number_of_days_until_end_of_year

      def self.call(previous_allowance, date)
        new(previous_allowance, date).call
      end

      def initialize(previous_allowance, date)
        @previous_allowance               = previous_allowance
        @days_in_a_year                   = Calendar.days_in_a_year(date)
        @number_of_days_until_end_of_year = Calendar.number_of_days_until_end_of_year(date)
      end

      def call
        number_of_days_until_end_of_year * (-previous_allowance / days_in_a_year)
      end
    end
  end
end
