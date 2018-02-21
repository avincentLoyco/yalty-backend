module API
  module V1
    class EmployeeBalancesController < API::ApplicationController
      include EmployeeBalanceSchemas
      authorize_resource except: :show, class: "Employee::Balance"

      def show
        authorize! :show, resource
        render_resource(resource)
      end

      def index
        if params[:time_off_category_id]
          render_resource(resources)
        else
          render json: ::Api::V1::EmployeeBalanceRepresenter.new(resources).balances_sum
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          if resource.resource_amount != 0
            attributes = attributes.merge(resource_amount: resource.resource_amount)
          end
          prepare_balances_to_update(resource, attributes)
          update_balances_job(resource.id, attributes)
          render_no_content
        end
      end

      private

      def resource
        @resource ||= Account.current.employee_balances.find(params[:id])
      end

      def resources
        @resources ||=
          if params[:time_off_category_id]
            employee_balances.where(time_off_category: time_off_category)
          else
            employee_balances
          end
      end

      def time_off_category
        TimeOffCategory.find(params[:time_off_category_id])
      end

      def employee_balances
        Account.current.employees.find(params[:employee_id]).employee_balances
      end

      def resource_representer
        ::Api::V1::EmployeeBalanceRepresenter
      end
    end
  end
end
