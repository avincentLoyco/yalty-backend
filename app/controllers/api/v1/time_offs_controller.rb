module API
  module V1
    class TimeOffsController < ApplicationController
      authorize_resource except: [:create, :index, :show]
      include TimeOffsRules

      def show
        authorize! :show, resource
        render_resource(resource)
      end

      def index
        authorize! :index, current_user
        render_resource(resources)
      end

      def create
        verified_params(gate_rules) do |attributes|
          resource = resources.new(time_off_attributes(attributes))
          authorize! :create, resource

          transactions do
            resource.save! &&
              create_new_employee_balance(resource)
          end

          render_resource(resource, status: :created)
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          transactions do
            resource.update!(attributes)
            prepare_balanaces_to_update(resource.employee_balance, balance_attributes)
          end

          update_balances_job(resource.employee_balance.id, balance_attributes)
          render_no_content
        end
      end

      def destroy
        next_balance = next_balance(resource.employee_balance)

        transactions do
          resource.employee_balance.destroy!
          resource.destroy!
          prepare_balanaces_to_update(resource.employee_balance, balance_attributes)
        end

        update_balances_job(next_balance.id, balance_attributes) if next_balance
        render_no_content
      end

      private

      def time_off_category
        @time_off_category ||= Account.current.time_off_categories.find(time_off_category_params)
      end

      def employee
        @employee ||= Account.current.employees.find(employee_params)
      end

      def resource
        @resource ||= Account.current.time_offs.find(params[:id])
      end

      def resources
        return time_off_category.time_offs if current_user.account_manager
        return TimeOff.none unless current_user.employee
        time_off_category.time_offs.where(employee: current_user.employee)
      end

      def employee_params
        params[:employee_id] ? params[:employee_id] : params[:employee][:id]
      end

      def time_off_category_params
        return params[:time_off_category][:id] unless params[:time_off_category_id]
        params[:time_off_category_id]
      end

      def time_off_attributes(attributes)
        attributes.tap do |attr|
          attr.delete(:employee)
          attr.delete(:time_off_category)
        end.merge(employee: employee, being_processed: true)
      end

      def create_new_employee_balance(resource)
        category = resource.time_off_category_id
        employee_id = resource.employee_id
        account = Account.current.id
        amount = resource.balance
        options = { time_off_id: resource.id }

        CreateEmployeeBalance.new(category, employee_id, account, amount, options).call
      end

      def resource_representer
        ::Api::V1::TimeOffsRepresenter
      end

      def balance_attributes
        { amount: resource.balance, effective_at: resource.start_time.to_s }
      end
    end
  end
end
