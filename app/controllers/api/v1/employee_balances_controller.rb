module API
  module V1
    class EmployeeBalancesController < API::ApplicationController
      include EmployeeBalanceRules

      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      def create
        verified_params(gate_rules) do |attributes|
          employee = find_employee(attributes)
          category = find_category(attributes)
          resource = CreateEmployeeBalance.new(category, employee, nil, attributes).call
          render_resource(resource)
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          CreateEmployeeBalance.new(resource.category, resource.employee, resource.policy, attributes)
          render_no_content
        end
      end

      def destroy
        resource.destroy!
      end

      private

      def find_employee(attributes)
        Account.current.employees.find(attributes.delete(:employee)[:id])
      end

      def find_category(attributes)
        Account.current.time_off_categories.find(attributes.delete(:time_off_category)[:id])
      end

      def resource
        @resource ||= Account.current.employee_balances.find(params[:id])
      end

      def resources
        @resources ||= params[:time_off_category_id] ?
          employee_balances.where(time_off_category_id: params[:time_off_category_id]).first :
            employee_balances
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
