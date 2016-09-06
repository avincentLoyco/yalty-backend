module API
  module V1
    class EmployeeBalancesController < API::ApplicationController
      include EmployeeBalanceSchemas
      before_action :verifiy_effective_at_and_validity_date, only: :update
      authorize_resource except: :show, class: 'Employee::Balance'

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
          prepare_balances_to_update(editable_resource, attributes)
          update_balances_job(editable_resource.id, attributes)
          render_no_content
        end
      end

      private

      def params_from_attributes(attributes)
        [
          attributes[:time_off_category][:id],
          attributes[:employee][:id],
          Account.current.id,
          options(attributes)
        ]
      end

      def options(attributes)
        attributes.reduce({}) do |options, (key, value)|
          options[key] = value if value.present?
          options
        end
      end

      def resource
        @resource ||= Account.current.employee_balances.find(params[:id])
      end

      def editable_resource
        @editable_resource = Account.current.employee_balances.find(params[:id])
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

      def verifiy_effective_at_and_validity_date
        validity_date = params[:validity_date] ? params[:validity_date] : resource.validity_date
        effective_at = params[:effective_at] ? params[:effective_at] : resource.effective_at
        return unless validity_date && effective_at && validity_date < effective_at
        raise InvalidResourcesError.new(resource, ['validity date must be after effective at'])
      end

      def resource_representer
        ::Api::V1::EmployeeBalanceRepresenter
      end
    end
  end
end
