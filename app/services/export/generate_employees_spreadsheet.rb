module Export
  class GenerateEmployeesSpreadsheet
    attr_reader :account, :archive_dir_path

    DEFAULT_EMPLOYEES_COLUMNS = ["Employee UUID", "Last name", "Last name (effective since)",
                                 "First name", "First name (effective since)",
                                 "Hired date", "Contract end date"].freeze

    def initialize(account, archive_dir_path)
      @account          = account
      @archive_dir_path = archive_dir_path
    end

    def call
      FileUtils.touch("#{archive_dir_path}/employees.csv")

      columns = DEFAULT_EMPLOYEES_COLUMNS
      columns += attribute_definition_columns

      CSV.open("#{archive_dir_path}/employees.csv", "wb") do |employee_csv|
        employee_csv << columns.flatten

        account.employees.each do |employee|
          row_data = employee_basic_data(employee)
          row_data += uniq_employee_attribute_definitions.map do |definition|
            employee_attribute_values(definition, employee)
          end
          employee_csv << row_data.flatten
        end
      end
    end

    private

    def attribute_definition_columns
      uniq_employee_attribute_definitions.map do |attribute_definition|
        attribute_fields = attribute_fields(attribute_definition["attribute_type"])

        if attribute_fields.count > 1
          attribute_fields.map do |field|
            ["#{attribute_definition["name"]}_#{field}",
             "#{attribute_definition["name"]}_#{field} (effective since)"]
          end
        else
          [attribute_definition["name"], "#{attribute_definition["name"]} (effective since)"]
        end
      end
    end

    def employee_basic_data(employee)
      firstname_attribute = latest_attribute(employee, "firstname")
      lastname_attribute  = latest_attribute(employee, "lastname")

      [
        employee.id,
        attribute_value(lastname_attribute.try(:[], "data")),
        attribute_effective_at(lastname_attribute),
        attribute_value(firstname_attribute.try(:[], "data")),
        attribute_effective_at(firstname_attribute),
        normalize_date(employee.hired_date),
        normalize_date(employee.contract_end_date)
      ]
    end

    def employee_attribute_values(attribute_definition, employee)
      attribute_fields       = attribute_fields(attribute_definition["attribute_type"])
      attribute              = latest_attribute(employee, attribute_definition["name"])
      attribute_effective_at = attribute_effective_at(attribute)
      attribute_value        = attribute_value(attribute.try(:[], "data"))

      if attribute_fields.count > 1
        attribute_fields.map do |field|
          if attribute_field_is_datetime?(attribute_definition["attribute_type"], field)
            [normalize_date(attribute_value.try(:[], field)&.to_datetime)]
          else
            [attribute_value.try(:[], field)]
          end << attribute_effective_at
        end
      elsif attribute_definition["attribute_type"].eql?("Date")
        [normalize_date(attribute_value&.to_date), attribute_effective_at]
      else
        [attribute_value, attribute_effective_at]
      end
    end

    def latest_attribute(employee, definition)
      attribute_versions_data.detect do |data|
        data["name"] == definition && data["employee_id"] == employee.id
      end
    end

    def basic_attribute(employee, type)
      attribute = employee.employee_attributes.find_by(attribute_name: type)
      return attribute unless attribute.nil?
      employee.employee_attribute_versions.select do |version|
        version.attribute_definition.name.eql?(type)
      end.first
    end

    def attribute_value(attribute_data)
      return if attribute_data.nil?
      attribute_data = JSON.parse(attribute_data)
      ::ActsAsAttribute::AttributeProxy.new(attribute_data).value
    end

    def attribute_effective_at(attribute_data)
      return if attribute_data.nil?
      normalize_date(attribute_data["effective_at"]&.to_date)
    end

    def attribute_fields(attribute_type)
      ::Attribute.const_get(attribute_type).attribute_set.map(&:name) - [:attribute_type]
    end

    def attribute_field_is_datetime?(attribute_type, attribute_name)
      ::Attribute.const_get(attribute_type)
                 .attribute_set[attribute_name]
                 .type.primitive.eql?(DateTime)
    end

    def attribute_versions_data
      attribute_names = uniq_employee_attribute_definitions.map do |attr|
        "'#{attr["name"]}'"
      end + ["'firstname'", "'lastname'"]

      @attribute_versions_data ||=
        ActiveRecord::Base.connection.exec_query("
          SELECT hstore_to_json(employee_attribute_versions.data) AS data,
                employee_events.effective_at,
                employee_attribute_definitions.name,
                employee_attribute_definitions.attribute_type,
                employees.id AS employee_id
          FROM employee_attribute_versions
          INNER JOIN employee_events
            ON employee_events.id=employee_attribute_versions.employee_event_id
          INNER JOIN employee_attribute_definitions
            ON employee_attribute_definitions.id=employee_attribute_versions.attribute_definition_id
          INNER JOIN employees
            ON employee_attribute_versions.employee_id=employees.id
          WHERE employees.account_id='#{account.id}'
            AND employee_attribute_definitions.name IN (#{attribute_names.join(", ")})
          ORDER BY employee_events.effective_at DESC
        ").to_hash
    end

    def uniq_employee_attribute_definitions
      @uniq_employee_attribute_definitions ||=
        ActiveRecord::Base.connection.exec_query("
          SELECT DISTINCT employee_attribute_definitions.name,
                          employee_attribute_definitions.attribute_type
          FROM employees
          INNER JOIN employee_attribute_versions
            ON employees.id=employee_attribute_versions.employee_id
          INNER JOIN employee_attribute_definitions
            ON employee_attribute_versions.attribute_definition_id=employee_attribute_definitions.id
          WHERE employees.account_id='#{account.id}'
            AND employee_attribute_definitions.name NOT IN ('firstname', 'lastname')
          ORDER BY employee_attribute_definitions.name
        ").to_hash
    end

    def normalize_date(date)
      date&.strftime("%d.%m.%Y")
    end
  end
end
