namespace :employee_event do
  desc "Migrate managers from event attributes to employee model property"
  task migrate_managers: :environment do
    class ManagerMigrator
      method_object :employee, :manager_name

      def call
        return unless manager
        employee.update(manager: manager)
      end

      private

      def manager
        @manager ||= employee.account.managers.detect do |manager|
          manager.employee.fullname == manager_name
        end
      end
    end

    Employee::AttributeDefinition.where(name: "manager")
      .includes(:employee_attributes)
      .flat_map(&:employee_attributes)
      .each do |attribute|
        ManagerMigrator.call(attribute.employee, attribute.value)
      end
  end
end
