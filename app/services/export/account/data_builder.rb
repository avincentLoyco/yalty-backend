module Export
  module Account
    class DataBuilder
      pattr_initialize :account

      def self.call(account)
        new(account).call
      end

      def call
        account.employees.map(&method(:generate_employee_attributes))
      end

      private

      def account_attribute_versions
        @account_attribute_versions ||= Export::Account::AttributeVersions::Get.call(account)
      end

      def account_work_and_marriage_events
        @account_work_and_marriage_events ||= Export::Account::Events::WorkAndMarriage.call(account)
      end

      def employee_attribute_versions(employee_id)
        account_attribute_versions.select { |attribute| attribute["employee_id"].eql?(employee_id) }
      end

      def employee_work_and_marriage_events(employee_id)
        account_work_and_marriage_events.select { |event| event["employee_id"].eql?(employee_id) }
      end

      def generate_employee_attributes(employee)
        Export::Employee::AttributesBuilder.call(
          employee,
          employee_attribute_versions(employee.id),
          employee_work_and_marriage_events(employee.id)
        )
      end
    end
  end
end
