module API
  module V1
    class WorkingPlacesController < ApplicationController
      authorize_resource except: :create
      include WorkingPlaceRules

      def index
        render_resource(resources)
      end

      def show
        render_resource(resource)
      end

      def create
        verified_params(gate_rules) do |attributes|
          related = related_params(attributes)
          related_joins_collection = related_joins_collection_params(attributes)
          @resource = Account.current.working_places.new(attributes)
          authorize! :create, resource

          result = transactions do
            resource.save &&
              assign_related(related) &&
              assign_related_joins_collection(related_joins_collection)
          end
          if result
            render_resource(resource, status: :created)
          else
            resource_invalid_error(resource)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          related = related_params(attributes)
          related_joins_collection = related_joins_collection_params(attributes)
          result = transactions do
            resource.update(attributes) &&
              assign_related(related) &&
              assign_related_joins_collection(related_joins_collection)
          end
          if result
            render_no_content
          else
            resource_invalid_error(resource)
          end
        end
      end

      def destroy
        if resource.employees.blank?
          resource.destroy!
          render_no_content
        else
          locked_error
        end
      end

      private

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

      def related_params(attributes)
        related = {}

        if attributes.key?(:holiday_policy)
          holiday_policy = { holiday_policy: attributes.delete(:holiday_policy) }
        end

        if attributes.key?(:presence_policy)
          presence_policy = { presence_policy: attributes.delete(:presence_policy) }
        end

        related
          .merge(holiday_policy.to_h)
          .merge(presence_policy.to_h)
      end

      def related_joins_collection_params(attributes)
        related_joins_collection = {}

        if attributes.key?(:time_off_policies)
          related_joins_collection[:time_off_policies] = attributes.delete(:time_off_policies)
        end

        related_joins_collection
      end

      def resources
        @resources ||= Account.current.working_places
      end

      def resource
        @resource ||= resources.find(params[:id])
      end

      def resource_representer
        ::Api::V1::WorkingPlaceRepresenter
      end
    end
  end
end
