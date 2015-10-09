module API
  module V1
    class WorkingPlacesController < ApplicationController
      include WorkingPlaceRules

      def index
        response = working_places.map do |working_place|
          WorkingPlaceRepresenter.new(working_place).complete
        end
        render json: response
      end

      def show
        render_json(working_place)
      end

      def create
        verified_params(gate_rules) do |attributes|
          employees = employees_params(attributes)
          working_place = Account.current.working_places.new(attributes)

          if working_place.save
            assign_employees(employees)
            render_json(working_place)
          else
            render_error_json(working_place)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          employees = employees_params(attributes)

          if working_place.update(attributes)
            assign_employees(employees)
            head 204
          else
            render_error_json(working_place)
          end
        end
      end

      def destroy
        working_place.destroy!
        head 204
      end

      private

      def assign_employees(employees)
        unless employees.nil?
          AssignCollection.new(working_place, employees, 'employees').call
        end
      end

      def employees_params(attributes)
        if attributes[:employees]
          employees_params = attributes.delete(:employees)
        end
      end

      def working_place
        @working_place ||= Account.current.working_places.find(params[:id])
      end

      def working_places
        @working_places ||= Account.current.working_places
      end

      def render_json(working_place)
        render json: WorkingPlaceRepresenter.new(working_place).complete
      end
    end
  end
end
