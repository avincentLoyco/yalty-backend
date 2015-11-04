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
          result = transactions do
            resource.save &&
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
          related = related_params(attributes)
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
        resource.destroy!
        head 204
      end

      private

      def assign_related(resource, related_records)
        return true if related_records.empty?
        related_records.each do |key, values|
          if key == :custom_holidays
            assign_holidays(resource, values)
          else
            AssignCollection.new(resource, values, key.to_s).call
          end
        end
      end

      def assign_holidays(resource, values)
        result = values.to_a.map { |holiday| holiday[:id] } & valid_holiday_ids
        if result.size != values.to_a.size
          fail ActiveRecord::RecordNotFound
        else
          Holiday.where(id: (resource.custom_holiday_ids - result)).destroy_all
          resource.custom_holiday_ids = result
        end
      end

      def related_params(attributes)
        related = {}
        employees = { employees: attributes.delete(:employees) } if attributes.key?(:employees)
        working_places = { working_places: attributes.delete(:working_places) } if attributes.key?(:working_places)
        custom_holidays = { custom_holidays: attributes.delete(:holidays) } if attributes.key?(:holidays)
        related = related.merge(employees.to_h)
        related = related.merge(working_places.to_h)
        related = related.merge(custom_holidays.to_h)
        related
      end

      def resource
        @resource ||= Account.current.holiday_policies.find(params[:id])
      end

      def resources
        @resources = Account.current.holiday_policies
      end

      def resource_representer
        ::Api::V1::HolidayPolicyRepresenter
      end

      def valid_holiday_ids
        Account.current.holiday_policies
          .map(&:custom_holidays).flatten.map { |holiday| holiday[:id] }
      end
    end
  end
end
