module API
  module V1
    class EmployeeBalancesController < API::ApplicationController
      include EmployeeBalanceRules

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
          category, employee, account, amount, options = category_id(attributes),
            employee_id(attributes), Account.current.id, params[:amount], find_options(attributes)

          resource = CreateEmployeeBalance.new(category, employee, account, amount, options).call
          render_resource(resource, status: :created)
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          update_balances_processed_flag(balances_to_update)

          UpdateBalanceJob.perform_later(resource.id, attributes)
          render_no_content
        end
      end

      def destroy
        balances_ids = balances_to_update - [resource.id, resource.balance_credit_removal.try(:id)]
        update_balances_processed_flag(balances_ids)
        next_balance_id = resource.next_balance

        resource.destroy!
        UpdateBalanceJob.perform_later(next_balance_id) if next_balance_id.present?
        render_no_content
      end

      private

      def find_options(attributes)
        params = {}
        params.merge!({ effective_at: attributes[:effective_at]  }) if attributes[:effective_at]
        params.merge!({ validity_date: attributes[:validity_date] }) if attributes[:validity_date]
        params
      end

      def employee_id(attributes)
        attributes.delete(:employee)[:id]
      end

      def category_id(attributes)
        attributes.delete(:time_off_category)[:id]
      end

      def resource
        @resource ||= Account.current.employee_balances.find(params[:id])
      end

      def resources
        @resources ||= !params[:time_off_category_id] ? employee_balances :
          employee_balances.where(time_off_category:
            TimeOffCategory.find(params[:time_off_category_id]))
      end

      def employee_balances
        @employee_balances ||= Account.current.employees
          .find(params[:employee_id]).employee_balances
      end

      def balances_to_update
        return [resource.id] if resource.last_in_policy?
        resource.validity_date.present? ? resource.all_later_ids : resource.later_balances_ids
      end

      def update_balances_processed_flag(ids)
        Employee::Balance.where(id: ids).update_all(beeing_processed: true)
      end

      def resource_representer
        ::Api::V1::EmployeeBalanceRepresenter
      end
    end
  end
end
