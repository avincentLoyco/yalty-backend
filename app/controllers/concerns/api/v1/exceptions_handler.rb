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
        else
          super(e)
        end
      end
    end
  end
end
