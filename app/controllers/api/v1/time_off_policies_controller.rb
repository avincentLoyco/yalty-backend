module API
  module V1
    class TimeOffPoliciesController < ApplicationController
      authorize_resource
      include TimeOffPoliciesRules

      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      def create
        verified_params(gate_rules) do |attributes|
          vefiry_category_belongs_to_current_account(attributes)
          related_joins_collection = related_joins_collection_params(attributes)
          create_params = get_create_params(attributes)
          @resource = TimeOffPolicy.new(create_params)
          authorize! :create, resource
          transactions do
            resource.save!
            assign_related_joins_collection(related_joins_collection)
          end
          render_resource(resource, status: :created)
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          vefiry_category_belongs_to_current_account(attributes)
          related = related_params(attributes)
          related_joins_collection = related_joins_collection_params(attributes)
          transactions do
            resource.update!(attributes)
            assign_related(related)
            assign_related_joins_collection(related_joins_collection)
          end
          render_no_content
        end
      end

      def destroy
        if resource.employee_balances.empty?
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
        unless params[:time_off_category_id]
          @resources ||=
            TimeOffPolicy.joins(:time_off_category)
              .where(time_off_categories: { account_id: Account.current.id })
        else
          time_off_category = { time_off_category: { id: params[:time_off_category_id] } }
          vefiry_category_belongs_to_current_account(time_off_category)
          @resources ||=
            TimeOffPolicy.joins(:time_off_category)
              .where(time_off_categories:
                { account_id: Account.current.id, id: params[:time_off_category_id] }
              )
        end
      end

      def vefiry_category_belongs_to_current_account(attributes)
        time_off_category_id = attributes[:time_off_category][:id]
        fail ActiveRecord::RecordNotFound unless
          Account.current.time_off_categories.pluck(:id).include?(time_off_category_id)
      end

      def resource_representer
        ::Api::V1::TimeOffPolicyRepresenter
      end

      def get_create_params(attributes)
        create_params = attributes.clone
        time_off_category = create_params.delete(:time_off_category)
        create_params[:time_off_category_id] = time_off_category[:id]
        create_params
      end

      def related_params(attributes)
        related = {}

        if attributes.key?(:time_off_category)
          related[:time_off_category] = attributes.delete(:time_off_category)
        end

        related
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

      def assign_related(related_records)
        return true if related_records.empty?
        related_records.each do |key, value|
          assign_member(resource, value.try(:[], :id), key.to_s)
        end
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
