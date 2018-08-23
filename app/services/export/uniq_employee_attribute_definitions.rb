module Export
  module Accounts
    module AttributeDefinitions
      class Get
        pattr_initialize :account

        def self.call(account)
          new(account).call
        end

        def call
          ActiveRecord::Base.connection.exec_query("
          SELECT employee_attribute_definitions.name,
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
      end
    end
  end
end
