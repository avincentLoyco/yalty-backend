module Export
  module Account
    module Events
      class WorkAndMarriage
        pattr_initialize :account

        def self.call(account)
          new(account).call
        end

        def call
          ActiveRecord::Base.connection.exec_query("
          SELECT latest_employee_events.employee_id,
          latest_employee_events.event_type,
          latest_employee_events.effective_at
          FROM (
            SELECT employee_id, event_type, MAX(effective_at) AS effective_at
            FROM employee_events
            GROUP BY employee_events.event_type, employee_events.employee_id
          ) AS latest_employee_events
          INNER JOIN employees
          ON employees.id = latest_employee_events.employee_id
          WHERE employees.account_id = '#{account.id}'
          AND latest_employee_events.event_type IN (#{statuses_query.join(",")})
          ORDER BY employees.id").to_hash
        end

        private

        def statuses_query
          (civil_events + work_events).map do |value|
            "'#{value}'"
          end
        end

        def civil_events
          ::Employee::CIVIL_STATUS.keys
        end

        def work_events
          %w(hired contract_end)
        end
      end
    end
  end
end
