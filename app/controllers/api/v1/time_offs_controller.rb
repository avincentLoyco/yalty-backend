module API
  module V1
    class TimeOffsController < ApplicationController
      include TimeOffsRules

      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      def create
        verified_params(gate_rules) do |attributes|
          resource = time_off_category.time_offs.new(time_off_attributes(attributes))
          if resource.save
            render_resource(resource, status: :created)
          else
            resource_invalid_error(resource)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          if resource.update(attributes)
            render_no_content
          else
            resource_invalid_error(resource)
          end
        end
      end

      def destroy
        resource.destroy!
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
        return time_off_category.time_offs unless params[:employee_id]
        time_off_category.time_offs.where(employee: employee)
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
        end.merge(employee: employee)
      end

      def resource_representer
        ::Api::V1::TimeOffsRepresenter
      end
    end
  end
end
