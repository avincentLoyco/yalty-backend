module API
  module V1
    class HolidayPoliciesController < ApplicationController
      include HolidayPolicyRules

      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      def create
        verified_params(gate_rules) do |attributes|
          related = related_params(attributes).compact
          resource = Account.current.holiday_policies.new(attributes)

          if resource.save
            assign_related(resource, related)
            render_resource(resource, status: :created)
          else
            resource_invalid_error(resource)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          related = related_params(attributes).compact

          if resource.update(attributes)
            assign_related(resource, related)
            render_no_content
          else
            resource_invalid_error(holiday_policy)
          end
        end
      end

      def destroy
        resource.destroy!
        head 204
      end

      private

      def assign_related(resource, related_records)
        return if related_records.empty?
        related_records.each do |related|
          key = related.keys.first
          AssignCollection.new(resource, related[key], key.to_s).call
        end
      end

      def related_params(attributes)
        [
          related_employees(attributes),
          related_working_places(attributes)
        ]
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

      def resource
        @resource ||= Account.current.holiday_policies.find(params[:id])
      end

      def resources
        @resources = Account.current.holiday_policies
      end

      def resource_representer
        HolidayPolicyRepresenter
      end
    end
  end
end
