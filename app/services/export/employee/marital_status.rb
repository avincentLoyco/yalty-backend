module Export
  module Employee
    class MaritalStatus
      attr_reader :employee_events

      def self.call(employee_events)
        new(employee_events).call
      end

      def initialize(employee_events)
        @employee_events = employee_events
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
          employee_events.select { |event| event["event_type"].in? ::Employee::CIVIL_STATUS.keys }
      end

      def latest_marital_event
        marital_events.max_by { |event| event_date(event) }
      end

      def status
        return "single" if latest_marital_event.blank?

        ::Employee::CIVIL_STATUS[latest_marital_event["event_type"]]
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
