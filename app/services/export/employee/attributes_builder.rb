module Export
  module Employee
    class AttributesBuilder
      attr_reader :employee_attributes_object

      def self.call(employee, employee_attribute_versions, employee_work_and_marriage_events)
        new(employee, employee_attribute_versions, employee_work_and_marriage_events).call
      end

      def initialize(employee, employee_attribute_versions, employee_work_and_marriage_events)
        @employee_attributes_object = Export::Employee::Attributes.new
        @employee = employee
        @employee_attribute_versions = employee_attribute_versions
        @employee_work_and_marriage_events = employee_work_and_marriage_events
      end

      def call
        set_basic_data
        set_attributes
        set_marital_data
        employee_attributes_object
      end

      def set_basic_data
        employee_attributes_object.basic = basic_data
      end

      def set_marital_data
        employee_attributes_object.plain[:marital_status] = build_attribute_data(
          marital_data[:status],
          marital_data[:date].presence,
          marital_data[:status],
        )
      end

      def set_attributes
        employee_attribute_versions.map do |employee_attribute|
          attribute_data      = JSON.parse(employee_attribute["data"])
          attribute_type      = attribute_data["attribute_type"]
          attribute_formatted = ::ActsAsAttribute::AttributeProxy.new(attribute_data).value

          if attribute_formatted.is_a?(String)
            employee_attributes_object.plain[employee_attribute["name"].to_sym] =
              build_attribute_data(
                attribute_formatted,
                employee_attribute["effective_at"],
                employee_attribute["event_type"]
              )
          elsif attribute_type.eql?("Child")
            employee_attributes_object.nested_array =
              count_children(attribute_formatted, employee_attribute)
          else
            employee_attributes_object.nested[employee_attribute["name"].to_sym] =
              build_attribute_data(
                attribute_formatted,
                employee_attribute["effective_at"],
                employee_attribute["event_type"]
              )
          end
        end
      end

      private

      attr_writer :employee_attributes_object
      attr_reader :employee, :employee_attribute_versions, :employee_work_and_marriage_events

      def basic_data
        {
          employee_id: employee.id,
          hired_date: work_event_date("hired"),
          contract_end_date: work_event_date("contract_end"),
        }
      end

      def build_attribute_data(attribute_data, effective_at, event_type)
        {
          value: attribute_data,
          effective_at: effective_at,
          event_type: event_type,
        }
      end

      def work_event_date(work_event)
        employee_work_and_marriage_events.find do |event|
          event["event_type"].eql?(work_event)
        end.try(:[], "effective_at")
      end

      def marital_data
        Export::Employee::MaritalStatus.call(employee_work_and_marriage_events)
      end

      def count_children(attribute_formatted, employee_attribute)
        Export::Employee::ChildCounter.call(
          children: employee_attributes_object.nested_array,
          attribute: attribute_formatted,
          effective_at: employee_attribute["effective_at"],
          event_type: employee_attribute["event_type"]
        )
      end
    end
  end
end
