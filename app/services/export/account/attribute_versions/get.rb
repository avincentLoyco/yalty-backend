module Export
  module Account
    module AttributeVersions
      class Get
        pattr_initialize :account

        def self.call(account)
          new(account).call
        end

        def call
          ActiveRecord::Base.connection.exec_query("
          SELECT hstore_to_json(employee_attribute_versions.data) AS data,
                employee_events.effective_at,
                employee_events.event_type,
                employee_attribute_definitions.name,
                employees.id AS employee_id
          FROM employee_attribute_versions
          INNER JOIN employee_events
            ON employee_events.id=employee_attribute_versions.employee_event_id
          INNER JOIN employee_attribute_definitions
            ON employee_attribute_definitions.id=employee_attribute_versions.attribute_definition_id
          INNER JOIN employees
            ON employee_attribute_versions.employee_id=employees.id
          WHERE employees.account_id='#{account.id}'
          AND employee_attribute_definitions.attribute_type!='File'
          ORDER BY employees.id, employee_events.effective_at
                                                   ").to_hash
        end
      end
    end
  end
end
