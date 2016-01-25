module API
  module V1
    class EmployeeBalancesController < API::ApplicationController
      include EmployeeBalanceRules

      def show
        render_resource(resource)
      end

      def index
        if params[:time_off_cateogry_id]
          render_resource(resources)
        else
          render json: ::Api::V1::EmployeeBalanceRepresenter.new(resources).balances_sum
        end
      end

      def create
        verified_params(gate_rules) do |attributes|
          category, employee, account, amount =
            category_id(attributes), employee_id(attributes), Account.current.id, params[:amount]
          CreateBalanceJob.perform_later(category, employee, account, amount)
          render_no_content
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          amount, employee_balances_ids = params[:amount], find_employees_balances_ids(attributes)
          update_balances_status(employee_balances_ids)
          UpdateBalanceJob.perform_later(amount, employee_balances_ids)
          render_no_content
        end
      end

      def destroy
        resource.destroy!
        render_no_content
      end

      private

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

      def resource_representer
        ::Api::V1::EmployeeBalanceRepresenter
      end

      def find_employees_balances_ids(attributes)
        return [resource.id] if resource.last_in_category?
        resource.later_balances_ids
      end

      def update_balances_status(ids)
        Employee::Balance.where(id: ids).update_all(beeing_processed: true)
      end
    end
  end
end
