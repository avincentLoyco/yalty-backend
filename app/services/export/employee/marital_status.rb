module Export
  module Employee
    class MaritalStatus
      MARITAL_EVENTS = %w(marriage divorce spouse_death).freeze

      attr_reader :employee_events

      def self.call(employee_events)
        new(employee_events).call
      end

      def initialize(employee_events)
        @employee_events = employee_events
        @marital_status = "single"
      end

      def call
        {
          status: status,
          date: event_date(latest_marital_event).to_s,
        }
      end

      private

      def marital_events
        @marital_events ||=
          employee_events.select { |event| MARITAL_EVENTS.include?(event["event_type"]) }
      end

      def latest_marital_event
        marital_events.max_by { |event| event_date(event) }
      end

      def status
        event_type = latest_marital_event.try(:[], "event_type")

        return @marital_status if [nil, "spouse_death"].include?(event_type)

        @marital_status = event_type.eql?("marriage") ? "married" : "divorced"
      end

      def event_date(event)
        event.try(:[], "effective_at").try(:to_date)
      end

      def event_by_type(type)
        employee_events.find { |event| event["event_type"].eql?(type) }
      end
    end
  end
end
