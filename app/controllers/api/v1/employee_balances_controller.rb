module API
  module V1
    class EmployeeBalancesController < API::ApplicationController
      include EmployeeBalanceRules
      include EmployeeBalanceUpdate

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
          effective_at, validity_date = attributes[:effective_at], attributes[:validity_date]

          transactions do
            manage_removal(validity_date.to_date) if attributes.has_key?(:validity_date)
            update_balances_processed_flag(balances_to_update(editable_resource, effective_at))
          end

          UpdateBalanceJob.perform_later(editable_resource.id, attributes)
          render_no_content
        end
      end

      def destroy
        update_balances_after_removed(editable_resource)
        editable_resource.destroy!
        render_no_content
      end

      private

      def options(attributes)
        params = {}
        params.merge!({ effective_at: attributes[:effective_at]  }) if attributes[:effective_at]
        params.merge!({ validity_date: attributes[:validity_date] }) if attributes[:validity_date]
        params
      end

      def params_from_attributes(attributes)
        [attributes[:time_off_category][:id], attributes[:employee][:id], Account.current.id,
         attributes[:amount], options(attributes)]
      end

      def params_from_resource
        [resource.time_off_category_id, resource.employee_id, Account.current.id, nil,
        { policy_credit_removal: true, skip_update: true, balance_credit_addition_id: resource.id,
          effective_at: params[:validity_date]} ]
      end

      def resource
        @resource ||= Account.current.employee_balances.find(params[:id])
      end

      def editable_resource
        @editable_resource = Account.current.employee_balances.editable.find(params[:id])
      end

      def resources
        @resources ||= params[:time_off_category_id] ?
          employee_balances.where(time_off_category: time_off_category) : employee_balances
      end

      def time_off_category
        TimeOffCategory.find(params[:time_off_category_id])
      end

      def resource_representer
        ::Api::V1::EmployeeBalanceRepresenter
      end

      def employee_balances
        Account.current.employees.find(params[:employee_id]).employee_balances
      end

      def manage_removal(new_date)
        return unless new_date.blank? || moved_to_past?(new_date) || moved_to_future?(new_date)

        new_date.blank? || moved_to_future?(new_date) ?
          resource.balance_credit_removal.try(:destroy!) : create_removal
      end

      def moved_to_past?(new_date, current_date = resource.validity_date)
        (current_date.blank? || current_date.to_date > Date.today) && new_date <= Date.today
      end

      def moved_to_future?(new_date, current_date = resource.validity_date)
        (current_date.blank? || current_date.to_date <= Date.today) && new_date > Date.today
      end

      def create_removal
        return unless resource.balance_credit_removal.blank?
        category, employee, account, amount, options = params_from_resource

        CreateEmployeeBalance.new(category, employee, account, amount, options).call
      end

      def verifiy_effective_at_and_validity_date
        validity_date = params[:validity_date] ? params[:validity_date] : resource.validity_date
        effective_at = params[:effective_at] ? params[:effective_at] : resource.effective_at
        return unless validity_date && effective_at && validity_date < effective_at
        fail InvalidResourcesError.new(resource, ['validity date must be after effective at'])
      end
    end
  end
end
