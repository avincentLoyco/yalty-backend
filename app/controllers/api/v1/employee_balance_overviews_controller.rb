module API
  module V1
    class EmployeeBalanceOverviewsController < API::ApplicationController
      include EmployeeBalanceOverviewSchemas

      def index
        verified_dry_params(dry_validation_schema) do
          render_resource resources
        end
      end

      def show
        verified_dry_params(dry_validation_schema) do
          render_resource resource
        end
      end

      private

      def resource
        balance_for(employee)
      end

      def resources
        employees.flat_map(&method(:balance_for))
      end

      def balance_for(employee)
        BalanceOverview::Generate.call(employee, **filters)
      end

      def resource_representer
        Api::V1::EmployeeBalanceOverviewRepresenter
      end

      def filters
        {
          category: verified_attributes[:category],
          date: verified_attributes[:date]
        }.compact
      end

      def employee
        @employee ||= employees.find_by!(id: params[:employee_id])
      end

      def employees
        Employee.accessible_by(current_ability).where(account: Account.current)
      end

      def verified_attributes
        dry_validation_schema.call(params).output
      end
    end
  end
end
