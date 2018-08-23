module Export
  module Employee
    class SpreadsheetColumnBuilder
      BASIC_EMPLOYEE_COLUMNS =
        [
          "employee_id",
          "lastname", "lastname (effective_at)",
          "firstname", "firstname (effective_at)",
          "hired_date",
          "contract_end_date",
          "marital_status", "marital_status (effective_at)"
        ].freeze

      pattr_initialize :attributes

      def self.call(attributes)
        new(attributes).call
      end

      def call
        {
          basic: BASIC_EMPLOYEE_COLUMNS,
          plain: default_columns,
          nested: nested_columns,
          nested_array: child_columns,
        }
      end

      private

      def default_columns
        deletable_columns = [:firstname, :lastname, :marital_status]
        default_columns = attributes.map(&:plain).map(&:keys).flatten.uniq - deletable_columns
        default_columns.sort.map { |attribute| attribute_with_effective_at(attribute) }
      end

      def nested_columns
        nested_columns_attributes = prepare_nested_attributes

        nested_columns = {}
        nested_columns_attributes.map do |attribute|
          nested_columns[attribute.first] = []
          attribute.second[:value].map do |value|
            nested_columns[attribute.first] <<
              attribute_with_effective_at("#{attribute.first}_#{value.first}")
          end
        end
        nested_columns
      end

      def child_columns
        child_columns = {}
        max_children_count = attributes.map(&:nested_array).map(&:count).max
        return {} if max_children_count.nil?

        1.upto(max_children_count) do |child_number|
          child_columns[child_number] = []
          attributes.map(&:nested_array).flatten.reduce({}, :merge)[:value].keys.map do |key|
            child_columns[child_number] <<
              attribute_with_effective_at("child_#{child_number}_#{key}")
          end
        end
        child_columns
      end

      def prepare_nested_attributes
        attributes.map(&:nested).map do |nested_attribute|
          nested_attribute.map do |attribute|
            attribute.second[:value].nil? ? nil : { attribute.first => attribute.second }
          end
        end.flatten.compact.reduce({}, :merge)
      end

      def attribute_with_effective_at(attribute_name)
        [
          attribute_name.to_s,
          "#{attribute_name} (effective_at)",
        ]
      end
    end
  end
end
