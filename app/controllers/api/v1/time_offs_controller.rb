module API
  module V1
    class TimeOffsController < ApplicationController
      authorize_resource except: [:create, :index, :show]
      include TimeOffsSchemas

      def show
        authorize! :show, resource
        render_resource(resource)
      end

      def index
        authorize! :index, current_user
        render_resource(resources)
      end

      def create
        convert_times_to_utc
        verified_dry_params(dry_validation_schema) do |attributes|
          resource = resources.new(time_off_attributes(attributes.except(:manual_amount)))
          authorize! :create, resource
          transactions do
            resource.save! && create_new_employee_balance(resource)
          end
          render_resource(resource, status: :created)
        end
      end

      def update
        convert_times_to_utc
        verified_dry_params(dry_validation_schema) do |attributes|
          previous_start_time = resource.start_time
          attributes_for_balance = balance_attributes(attributes, previous_start_time)

          transactions do
            resource.update!(attributes.except(:manual_amount))
            prepare_balances_to_update(resource.employee_balance, attributes_for_balance)
          end

          update_balances_job(resource.employee_balance.id, attributes_for_balance)
          render_no_content
        end
      end

      def destroy
        next_balance = next_balance(resource.employee_balance)

        transactions do
          resource.employee_balance.destroy!
          resource.destroy!
          prepare_balances_to_update(resource.employee_balance, balance_attributes)
        end

        update_balances_job(next_balance, update_all: true) if next_balance
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
        CreateEmployeeBalance.new(
          resource.time_off_category_id,
          resource.employee_id,
          Account.current.id,
          time_off_id: resource.id,
          resource_amount: resource.balance,
          manual_amount: params[:manual_amount] || 0,
          validity_date: find_validity_date(resource),
          effective_at: resource.end_time
        ).call
      end

      def resource_representer
        ::Api::V1::TimeOffsRepresenter
      end

      def balance_attributes(verified_params = {}, previous_start_time = nil)
        {
          manual_amount: verified_params[:manual_amount] ? verified_params[:manual_amount] : 0,
          resource_amount: resource.balance,
          effective_at: find_effective_at(previous_start_time).to_s
        }
      end

      def convert_times_to_utc
        return unless params[:start_time].present? && params[:end_time].present?
        params[:start_time] = params.delete(:start_time) + '+00:00'
        params[:end_time] = params.delete(:end_time) + '+00:00'
      end

      def find_validity_date(resource)
        active_policy =
          employee.active_policy_in_category_at_date(time_off_category.id, resource.end_time)

        RelatedPolicyPeriod.new(active_policy).validity_date_for_balance_at(resource.end_time)
      end

      def find_effective_at(previous_start_time)
        if previous_start_time && previous_start_time < resource.start_time
          previous_start_time
        else
          resource.start_time
        end
      end
    end
  end
end
