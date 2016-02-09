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
          category, employee, account, amount, options = category_id(attributes),
            employee_id(attributes), Account.current.id, params[:amount], find_options(attributes)

          resources = CreateEmployeeBalance.new(category, employee, account, amount, options).call
          render_resource(resources, status: :created)
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          create_removal_if_in_past(attributes)
          update_balances_processed_flag(balances_to_update(attributes[:effective_at]))

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

      def balances_to_update(effective_at = nil)
        return [resource.id] if resource.last_in_policy? && effective_at.blank?
        if resource.validity_date.present? || effective_at
          return resource.all_later_ids unless effective_at && effective_at < resource.effective_at
          resource.all_later_ids(effective_at)
        else
          resource.later_balances_ids
        end
      end

      def update_balances_processed_flag(ids)
        Employee::Balance.where(id: ids).update_all(beeing_processed: true)
      end

      def resource_representer
        ::Api::V1::EmployeeBalanceRepresenter
      end

      def create_removal_if_in_past(attributes)
        return unless attributes[:validity_date] && moved_to_past?(attributes[:validity_date])

        category, employee, account, amount, options =
          resource.time_off_category_id, resource.employee_id, Account.current.id, nil,
            { policy_credit_removal: true, skip_update: true, balance_credit_addition_id: resource.id }

        CreateEmployeeBalance.new(category, employee, account, amount, options).call
      end

      def moved_to_past?(date)
        !resource.time_off_policy.previous_period.include?(resource.validity_date) &&
          resource.time_off_policy.previous_period.include?(date.to_date)
      end

      def verifiy_effective_at_and_validity_date
        return unless params[:validity_date] || params[:effective_at]
        validity_date = params[:validity_date] ? params[:validity_date] : resource.validity_date
        effective_at = params[:effective_at] ? params[:effective_at] : resource.effective_at

        if validity_date.to_date < effective_at.to_date
          fail InvalidResourcesError.new(resource, ['validity date must be after effective at'])
        end
      end
    end
  end
end
