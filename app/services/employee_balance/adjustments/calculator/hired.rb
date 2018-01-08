module Adjustments
  module Calculator
    class Hired
      include Calendar

      attr_reader :current_allowance, :days_in_a_year, :number_of_days_until_end_of_year

      def self.call(current_allowance, date)
        new(current_allowance, date).call
      end

      def initialize(current_allowance, date)
        @current_allowance                = current_allowance
        @days_in_a_year                   = Calendar.days_in_a_year(date)
        @number_of_days_until_end_of_year = Calendar.number_of_days_until_end_of_year(date)
      end

      def call
        current_allowance / days_in_a_year * number_of_days_until_end_of_year
      end
    end
  end
end
