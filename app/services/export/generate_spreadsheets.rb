module Export
  class GenerateSpreadsheets
    attr_reader :account, :archive_dir_path

    DEFAULT_EMPLOYEES_COLUMNS     = ['Employee UUID', 'Last name', 'Last name (effective since)',
                                     'First name', 'First name (effective since)',
                                     'Hired date', 'Contract end date'].freeze
    DEFAULT_WORKING_HOURS_COLUMNS = ['Employee UUID', 'Date', 'Comment'].freeze
    DEFAULT_TIME_OFFS_COLUMNS     = ['Employee UUID', 'Category', 'From', 'To'].freeze

    def initialize(account, archive_dir_path)
      @account          = account
      @archive_dir_path = archive_dir_path
    end

    def call
      generate_employees_csv
      generate_working_hours_csv
      generate_time_off_csv
    end

    private

    def generate_employees_csv
      FileUtils.touch("#{archive_dir_path}/employees.csv")

      columns = DEFAULT_EMPLOYEES_COLUMNS
      columns += attribute_definition_columns(uniq_employee_attribute_definitions)

      CSV.open("#{archive_dir_path}/employees.csv", 'wb') do |employee_csv|
        employee_csv << columns.flatten

        account.employees.each do |employee|
          attributes = employee.employee_attributes
          row_data   = employee_basic_data(employee, attributes)

          row_data += uniq_employee_attribute_definitions.map do |definition|
            employee_attribute_values(attributes, definition)
          end
          employee_csv << row_data.flatten
        end
      end
    end

    def generate_working_hours_csv
      FileUtils.touch("#{archive_dir_path}/working_hours.csv")
      working_times = RegisteredWorkingTime
                      .where(employee_id: account.employees.pluck(:id))
                      .order(:employee_id)

      max_time_entries_count = working_times.pluck(:time_entries).map(&:size).max.to_i

      columns = DEFAULT_WORKING_HOURS_COLUMNS
      columns += (1..max_time_entries_count).map { |number| "Timestamp #{number}" }

      CSV.open("#{archive_dir_path}/working_hours.csv", 'wb') do |working_times_csv|
        working_times_csv << columns

        working_times.each do |record|
          row = [record.employee_id, record.date.strftime('%d.%m.%Y'), record.comment]
          row += record.time_entries.map do |time_entry|
            "#{time_entry['start_time']} - #{time_entry['end_time']}"
          end
          working_times_csv << row
        end
      end
    end

    def generate_time_off_csv
      FileUtils.touch("#{archive_dir_path}/time_offs.csv")

      CSV.open("#{archive_dir_path}/time_offs.csv", 'wb') do |time_offs_csv|
        time_offs_csv << DEFAULT_TIME_OFFS_COLUMNS

        account.time_offs.each do |time_off|
          time_offs_csv << [
            time_off.employee_id,
            time_off.time_off_category.name,
            time_off.start_time.strftime('%Y.%m.%d %T'),
            time_off.end_time.strftime('%Y.%m.%d %T')
          ]
        end
      end
    end

    def employee_basic_data(employee, attributes)
      firstname_attribute = attributes.find_by(attribute_name: 'firstname')
      lastname_attribute  = attributes.find_by(attribute_name: 'lastname')

      [
        employee.id,
        lastname_attribute&.value,
        lastname_attribute&.effective_at&.strftime('%d.%m.%Y'),
        firstname_attribute&.value,
        firstname_attribute&.effective_at&.strftime('%d.%m.%Y'),
        employee.hired_date.strftime('%d.%m.%Y'),
        employee.contract_end_date&.strftime('%d.%m.%Y')
      ]
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
            AND employee_attribute_definitions.name NOT IN ('firstname', 'lastname');
        ").to_hash
    end

    def attribute_definition_columns(attribute_definitions)
      attribute_definitions.map do |attribute_definition|
        attribute_fields = attribute_fields(attribute_definition['attribute_type'])

        if attribute_fields.count > 1
          attribute_fields.map do |field|
            ["#{attribute_definition['name']}_#{field}",
             "#{attribute_definition['name']}_#{field} (effective since)"]
          end
        else
          [attribute_definition['name'], "#{attribute_definition['name']} (effective since)"]
        end
      end
    end

    def employee_attribute_values(attributes, attribute_definition)
      attribute_fields       = attribute_fields(attribute_definition['attribute_type'])

      attribute              = attributes.find_by(attribute_name: attribute_definition['name'])
      attribute_effective_at = attribute&.effective_at&.strftime('%d.%m.%Y')
      attribute_value        = attribute&.value

      if attribute_fields.count > 1
        attribute_fields.map do |field|
          if attribute_field_is_datetime?(attribute_definition['attribute_type'], field)
            [attribute_value.try(:[], field)&.to_datetime&.strftime('%d.%m.%Y')]
          else
            [attribute_value.try(:[], field)]
          end << attribute_effective_at
        end
      else
        [attribute_value, attribute_effective_at]
      end
    end

    def attribute_fields(attribute_type)
      ::Attribute.const_get(attribute_type).attribute_set.map(&:name) - [:attribute_type]
    end

    def attribute_field_is_datetime?(attribute_type, attribute_name)
      ::Attribute.const_get(attribute_type)
                 .attribute_set[attribute_name]
                 .type.primitive.eql?(DateTime)
    end
  end
end
