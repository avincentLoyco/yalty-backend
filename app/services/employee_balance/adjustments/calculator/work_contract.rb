module Adjustments
  module Calculator
    class WorkContract
      include Calendar

      attr_reader :current_allowance, :previous_allowance, :days_in_a_year,
        :number_of_days_until_end_of_year, :date

      def self.call(current_allowance, previous_allowance, date)
        new(current_allowance, previous_allowance, date).call
      end

      def initialize(current_allowance, previous_allowance, date)
        @current_allowance                = current_allowance
        @previous_allowance               = previous_allowance
        @days_in_a_year                   = Calendar.days_in_a_year(date)
        @number_of_days_until_end_of_year = Calendar.number_of_days_until_end_of_year(date)
        @date                             = date
      end

      def call
        return current_allowance if date.month.eql?(1) && date.day.eql?(1)
        calculated_annual_allowance = -previous_allowance + current_allowance
        calculated_annual_allowance / days_in_a_year * number_of_days_until_end_of_year
      end
    end
  end
end
