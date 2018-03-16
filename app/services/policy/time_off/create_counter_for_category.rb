module Policy
  module TimeOff
    class CreateCounterForCategory
      attr_reader :time_off_category

      def self.call(time_off_category)
        new(time_off_category).call
      end

      def initialize(time_off_category)
        @time_off_category = time_off_category
      end

      def call
        TimeOffPolicy.create!(
          start_day: 1,
          start_month: 1,
          policy_type: "counter",
          time_off_category_id: time_off_category.id,
          name: time_off_category.name
        )
      end
    end
  end
end
