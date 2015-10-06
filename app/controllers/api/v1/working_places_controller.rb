module API
  module V1
    class WorkingPlacesController < ApplicationController
      def show
        rules = gate_member_rule

        with_verified_params(rules) do |attributes|
          render json: WorkingPlaceRepresenter.new(working_place).basic
        end
      end

      def index
        render json: WorkingPlacesRepresenter.new(working_places).basic
      end

      def create
        rules = Gate.rules do
          required :name, :String
          optional :employees, :Array
          optional :type, :String
        end

        with_verified_params(rules) do |attributes|
          if attributes[:employees]
            attributes[:employees] = valid_employees(attributes[:employees])
          end
          working_place = Account.current.working_places.create(attributes)
          if working_place.save
            render json: WorkingPlaceRepresenter.new(working_place).basic
          else
            render json: ErrorsRepresenter.new(working_place.errors.messages, 'settings').resource,
              status: 422
          end
        end
      end

      def update
        rules = Gate.rules do
          required :id, :String
          optional :name, :String
          optional :employees, :Array
          optional :type, :String
        end

        with_verified_params(rules) do |attributes|
          if attributes[:employees]
            assign_employees(attributes[:employees])
            attributes.delete(:employees)
          end
          if working_place.update(attributes)
            render json: WorkingPlaceRepresenter.new(working_place).basic
          else
            render json: ErrorsRepresenter.new(working_place.errors.messages, 'settings').resource,
              status: 422
          end
        end
      end

      def destroy
        rules = gate_member_rule

        with_verified_params(rules) do |attributes|
          working_place.destroy!
          head 204
        end
      end

      private

      def assign_employees(employees)
        working_place.employees.push(valid_employees(employees))
      end

      def valid_employees(employees)
        employee_ids = employees.map { |employee| employee[:id] }
        employees = []
        employee_ids.each do |id|
          employees.push(Account.current.employees.find(id))
        end
        employees
      end

      def working_place
        @working_place ||= Account.current.working_places.find(params[:id])
      end

      def working_places
        @working_places ||= Account.current.working_places
      end
    end
  end
end
