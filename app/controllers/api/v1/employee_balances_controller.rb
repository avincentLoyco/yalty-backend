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
          category, employee, policy, params = balance_params(attributes)
          resource = CreateEmployeeBalance.new(category, employee, policy, params).call
          render_resource(resource, status: :created)
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          category, employee, policy, params = balance_params(attributes)
          resource = CreateEmployeeBalance.new(category, employee, policy, params).call
          render_no_content
        end
      end

      def destroy
        resource.destroy!
        render_no_content
      end

      private

      def balance_params(attributes)
        if request.put?
          [resource.time_off_category, resource.employee, resource.time_off_policy, attributes]
        else
          [category(attributes), employee(attributes), nil, attributes]
        end
      end

      def employee(attributes)
        Account.current.employees.find(attributes.delete(:employee)[:id])
      end

      def category(attributes)
        Account.current.time_off_categories.find(attributes.delete(:time_off_category)[:id])
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
    end
  end
end
