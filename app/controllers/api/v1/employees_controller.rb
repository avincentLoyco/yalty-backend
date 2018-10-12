# frozen_string_literal: true

module API
  module V1
    class EmployeesController < ApplicationController
      include AppDependencies[
        get_employees: "use_cases.employees.index",
        get_employee: "use_cases.employees.show",
        destroy_employee: "use_cases.employees.destroy",
      ]

      authorize_resource

      def show
        render_resource(resource)
      end

      def index
        render_resources
      end

      def destroy
        authorize! :destroy, resource
        destroy_employee.call(resource)
        render_no_content
      end

      private

      def resource_representer
        if current_user.owner_or_administrator? ||
            (@resource && current_user.employee.try(:id) == @resource.id)
          ::Api::V1::EmployeeRepresenter
        else
          ::Api::V1::PublicEmployeeRepresenter
        end
      end

      def render_resources
        response = resources.map do |employee|
          if current_user.owner_or_administrator? || current_user.employee.try(:id) == employee.id
            ::Api::V1::EmployeeRepresenter.new(employee).complete
          else
            ::Api::V1::PublicEmployeeRepresenter.new(employee).complete
          end
        end
        render json: response
      end

      def resource
        @resource ||= get_employee.call(params[:id])
      end

      def resources
        @resources ||= get_employees.call(status: params[:status])
      end
    end
  end
end
