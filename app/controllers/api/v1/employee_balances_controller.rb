module API
  module V1
    class EmployeeBalancesController < API::ApplicationController
      include EmployeeBalanceRules

      before_action :verifiy_effective_at_and_validity_date, only: :update

      def show
        render_resource(resource)
      end

      def index
        if params[:time_off_category_id]
          render_resource(resources)
        else
          render json: ::Api::V1::EmployeeBalanceRepresenter.new(resources).balances_sum
        end
      end

      def create
        verified_params(gate_rules) do |attributes|
          category, employee, account, amount, options = params_from_attributes(attributes)

          resources = CreateEmployeeBalance.new(category, employee, account, amount, options).call
          render_resource(resources, status: :created)
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          validity_date = attributes[:validity_date]

          transactions do
            if attributes.key?(:validity_date)
              ManageEmployeeBalanceRemoval.new(validity_date, resource).call
            end
            prepare_balances_to_update(editable_resource, attributes)
          end

          update_balances_job(editable_resource.id, attributes)
          render_no_content
        end
      end

      def destroy
        next_balance = next_balance(resource)

        transactions do
          resource_to_delete = editable_resource
          editable_resource.destroy!
          prepare_balances_to_update(resource_to_delete) if next_balance
        end

        update_balances_job(next_balance) if next_balance
        render_no_content
      end

      private

      def options(attributes)
        params = {}
        params[:effective_at] = attributes[:effective_at] if attributes[:effective_at]
        params[:validity_date] = attributes[:validity_date] if attributes[:validity_date]
        params
      end

      def params_from_attributes(attributes)
        [attributes[:time_off_category][:id], attributes[:employee][:id], Account.current.id,
         attributes[:amount], options(attributes)]
      end

      def resource
        @resource ||= Account.current.employee_balances.find(params[:id])
      end

      def editable_resource
        @editable_resource = Account.current.employee_balances.editable.find(params[:id])
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
