module API
  module V1
    class TimeOffPoliciesController < ApplicationController
      authorize_resource
      include TimeOffPoliciesSchemas

      def show
        render json: resource_representer.new(resource).with_relationships
      end

      def index
        render json:
          resources.not_reset.map { |item| resource_representer.new(item).with_relationships }
      end

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          verify_category_belongs_to_current_account(attributes[:time_off_category][:id])
          obligatory_params = get_obligatory_params(attributes)
          @resource = TimeOffPolicy.new(obligatory_params)
          transactions do
            resource.save!
          end
          render_resource(resource, status: :created)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          transactions do
            resource.update!(attributes)
          end
          render_no_content
        end
      end

      def destroy
        if resource.employee_time_off_policies.empty?
          resource.destroy!
          render_no_content
        else
          render_locked_error(controller_name, "employees")
        end
      end

      private

      def resource
        @resource ||= Account.current.time_off_policies.find(params[:id])
      end

      def resources
        @resources =
          if params[:time_off_category_id]
            verify_category_belongs_to_current_account(params[:time_off_category_id])
            filter_by_status.where(time_off_category_id: params[:time_off_category_id])
          else
            filter_by_status
          end
      end

      def filter_by_status
        status = params[:status] ? params[:status].eql?("active") : true
        Account.current.time_off_policies.where(active: status)
      end

      def verify_category_belongs_to_current_account(time_off_category_id)
        raise ActiveRecord::RecordNotFound unless
          Account.current.time_off_categories.pluck(:id).include?(time_off_category_id)
      end

      def resource_representer
        ::Api::V1::TimeOffPolicyRepresenter
      end

      def get_obligatory_params(attributes)
        obligatory_params = attributes.clone
        time_off_category = obligatory_params.delete(:time_off_category)
        obligatory_params[:time_off_category_id] = time_off_category[:id]
        obligatory_params
      end
    end
  end
end
