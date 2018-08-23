module Export
  module Employee
    class SpreadsheetDataBuilder
      pattr_initialize :attributes, :columns

      def self.call(attributes, columns)
        new(attributes, columns).call
      end

      def call
        attributes.map do |employee_attributes|
          [
            build_basic_employee_data(employee_attributes),
            build_default_employee_data(employee_attributes),
            build_nested_employee_data(employee_attributes),
            build_nested_array_employee_data(employee_attributes),
          ]
        end
      end

      private

      def build_basic_employee_data(employee_attributes)
        [
          employee_attributes.basic[:employee_id],
          employee_attributes.plain[:lastname].try(:[], :value),
          employee_attributes.plain[:lastname].try(:[], :effective_at),
          employee_attributes.plain[:firstname].try(:[], :value),
          employee_attributes.plain[:firstname].try(:[], :effective_at),
          employee_attributes.basic[:hired_date],
          employee_attributes.basic[:contract_end_date],
          employee_attributes.plain[:marital_status].try(:[], :value),
          employee_attributes.plain[:marital_status].try(:[], :effective_at),
        ]
      end

      def build_default_employee_data(employee_attributes)
        columns[:plain].map do |attribute|
          [
            fetch_attribute(employee_attributes.plain, attribute.first.to_sym, :value),
            fetch_attribute(employee_attributes.plain, attribute.first.to_sym, :effective_at),
          ]
        end
      end

      def build_nested_employee_data(employee_attributes)
        columns[:nested].keys.map do |attribute_name|
          columns[:nested][attribute_name].map do |nested_attribute|
            nested_attribute_name = nested_attribute(attribute_name, nested_attribute.first.dup)
            fetch_nested_attribute(
              employee_attributes.nested,
              attribute_name.to_sym,
              nested_attribute_name
            )
          end
        end
      end

      def nested_attribute(attribute_name, nested_attribute_name)
        nested_attribute_name.slice!("#{attribute_name}_")
        nested_attribute_name
      end

      def build_nested_array_employee_data(employee_attributes)
        columns[:nested_array].map do |nested_data_array|
          nested_data_array.second.map do |nested_data|
            nested_data_attribute_name =
              nested_attribute("child_#{nested_data_array.first}", nested_data.first.dup)

            fetch_nested_attribute(
              employee_attributes.nested_array,
              nested_data_array.first - 1,
              nested_data_attribute_name
            )
          end
        end
      end

      def fetch_nested_attribute(attributes, attribute_name, nested_attribute_name)
        attribute_value = fetch_attribute(
          attributes,
          attribute_name,
          :value
        ).try(:[], nested_attribute_name.to_sym)

        effective_at = fetch_attribute(
          attributes,
          attribute_name,
          :effective_at
        )
        attribute_effective_at = effective_at if attribute_value.present?

        [attribute_value, attribute_effective_at]
      end

      def fetch_attribute(attributes, attribute_name, field)
        attributes.fetch(attribute_name, nil).try(:[], field)
      end
    end
  end
end
