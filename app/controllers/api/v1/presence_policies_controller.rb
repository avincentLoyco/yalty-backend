module API
  module V1
    class PresencePoliciesController < ApplicationController
      include PresencePolicyRules

      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      def create
        verified_params(gate_rules) do |attributes|
          related = related_params(attributes).compact
          resource = Account.current.presence_policies.new(attributes)
          result = transactions do
            resource.save!
            assign_related(resource, related)
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
          related = related_params(attributes).compact
          result = transactions do
            resource.update(attributes) &&
            assign_related(resource, related)
          end
          if result
            render_no_content
          else
            resource_invalid_error(resource)
          end
        end
      end

      def destroy
        if resource.employees.empty? && resource.working_places.empty?
          resource.destroy!
          render_no_content
        else
          locked_error
        end
      end

      private

      def related_params(attributes)
        related_employees(attributes).to_h
          .merge(related_working_places(attributes).to_h)
          .merge(related_presence_days(attributes).to_h)
      end

      def related_employees(attributes)
        if attributes[:employees]
          { employees: attributes.delete(:employees) }
        end
      end

      def related_working_places(attributes)
        if attributes[:working_places]
          { working_places: attributes.delete(:working_places) }
        end
      end

      def related_presence_days(attributes)
        if attributes[:presence_days]
          { presence_days: attributes.delete(:presence_days) }
        end
      end

      def assign_related(resource, related_records)
        return true if related_records.empty?
        related_records.each do |key, values|
          if key == :presence_days
            assign_presence_days(resource, values)
          else
            AssignCollection.new(resource, values, key.to_s).call
          end
        end
      end

      def assign_presence_days(resource, values)
        result = values.map { |value| value[:id] } & valid_presence_days_ids
        if result.size != values.size
          raise ActiveRecord::RecordNotFound
        else
          PresenceDay.where(id: (resource.presence_day_ids - result)).destroy_all
          resource.presence_day_ids = result
        end
      end

      def valid_presence_days_ids
        Account.current.presence_policies.map(&:presence_days)
          .flatten.map { |presence_day| presence_day[:id] }
      end

      def resource
        @resource ||= resources.find(params[:id])
      end

      def resources
        @resources ||= Account.current.presence_policies
      end

      def resource_representer
        ::V1::PresencePolicyRepresenter
      end
    end
  end
end
