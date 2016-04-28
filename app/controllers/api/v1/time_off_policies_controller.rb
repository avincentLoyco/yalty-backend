module API
  module V1
    class TimeOffPoliciesController < ApplicationController
      authorize_resource
      include TimeOffPoliciesRules

      def show
        render json: resource_representer.new(resource).with_relationships
      end

      def index
        render json: resources.map { |item| resource_representer.new(item).with_relationships }
      end

      def create
        verified_params(gate_rules) do |attributes|
          vefiry_category_belongs_to_current_account(attributes[:time_off_category][:id])
          related_joins_collection = related_joins_collection_params(attributes)
          obligatory_params = get_obligatory_params(attributes)
          @resource = TimeOffPolicy.new(obligatory_params)
          transactions do
            resource.save!
            assign_related_joins_collection(related_joins_collection)
          end
          render_resource(resource, status: :created)
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          related_joins_collection = related_joins_collection_params(attributes)
          transactions do
            resource.update!(attributes)
            assign_related_joins_collection(related_joins_collection)
          end
          render_no_content
        end
      end

      def destroy
        if resource.employee_time_off_policies.empty? &&
            resource.working_place_time_off_policies.empty?
          resource.destroy!
          render_no_content
        else
          locked_error
        end
      end

      private

      def resource
        @resource ||= resources.find(params[:id])
      end

      def resources
        if params[:time_off_category_id]
          vefiry_category_belongs_to_current_account(params[:time_off_category_id])
          @resources ||=
            TimeOffPolicy.for_account_and_category(
              Account.current.id,
              params[:time_off_category_id]
            )
        else
          @resources ||= Account.current.time_off_policies
        end
      end

      def vefiry_category_belongs_to_current_account(time_off_category_id)
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

      def related_joins_collection_params(attributes)
        related_joins_collection = {}

        if attributes.key?(:employees)
          related_joins_collection[:employees] = attributes.delete(:employees)
        end

        if attributes.key?(:working_places)
          related_joins_collection[:working_places] = attributes.delete(:working_places)
        end

        related_joins_collection
      end

      def assign_related_joins_collection(related_records)
        return true if related_records.empty?
        related_records.each do |key, hash_array|
          assign_join_table_collection(resource, hash_array, key.to_s)
        end
      end
    end
  end
end
