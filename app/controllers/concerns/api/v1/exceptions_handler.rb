require 'active_support/concern'
require 'jsonapi/exceptions'

module JSONAPI
  module Exceptions
    class EntityAlreadyExists < Error
      def initialize(id)
        @id = id
      end

      def errors
        [
          JSONAPI::Error.new(
            code: JSONAPI::SAVE_FAILED,
            status: :conflict,
            title: 'Entity already exists',
            detail: "Entity with id '#{@id} already exists'"
          )
        ]
      end
    end

    class ForbiddenAccess < Error
      def initialize(id)
        @id = id
      end

      def errors
        [
          JSONAPI::Error.new(
            code: JSONAPI::SAVE_FAILED,
            status: :forbidden,
            title: 'Access to resource forbidden',
            detail: "Can not use entity with id '#{@id}'"
          )
        ]
      end
    end

    class ForbiddenAction < Error
      def initialize(action)
        @action = action
      end

      def errors
        [
          JSONAPI::Error.new(
            code: JSONAPI::SAVE_FAILED,
            status: :forbidden,
            title: 'Action forbidden',
            detail: "Action '#{@action}' forbidden"
          )
        ]
      end
    end
  end
end

module API
  module V1
    module ExceptionsHandler
      extend ActiveSupport::Concern

      def handle_exceptions(e)
        case e
        when ActionController::ParameterMissing
          errors = JSONAPI::Exceptions::ParameterMissing.new(e.param).errors
          render_errors(errors)
        when ActiveRecord::RecordNotFound
          render_errors(JSONAPI::Exceptions::RecordNotFound.new(e).errors) && return
        when API::V1::Exceptions::Forbidden
          render_errors(JSONAPI::Exceptions::ForbiddenAccess.new(e).errors) && return
        when API::V1::Exceptions::ForbiddenAction
          render_errors(JSONAPI::Exceptions::ForbiddenAction.new(e).errors) && return
        else
          super(e)
        end
      end
    end
  end
end
