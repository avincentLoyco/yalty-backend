module API
  module V1
    class FileStorageTokensController < ApplicationController
      include TokensSchemas

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          file_not_found!(attributes[:file_id])
          wrong_duration!(attribute_version(attributes[:file_id]), attributes[:duration])
          authorize! :create, :tokens, attributes[:file_id], attribute_version(attributes[:file_id])
          render json: SaveFileStorageTokenToRedis.new(attributes).call, status: 201
        end
      end

      private

      def file_not_found!(file_id)
        return unless file_id.present? && !EmployeeFile.exists?(id: file_id)
        raise ActiveRecord::RecordNotFound
      end

      def wrong_duration!(attr_version, duration)
        return unless attr_version.present? && incorrect_duration?(attr_version, duration)
        message = { duration: 'Requested longterm token when not allowed' }
        raise InvalidParamTypeError.new(attr_version, message)
      end

      def incorrect_duration?(attr_version, duration)
        duration.present? && duration.eql?('longterm') &&
          !attr_version.attribute_definition.long_token_allowed
      end

      def attribute_version(file_id)
        @attribute_version ||= begin
          return unless file_id.present?
          Account.current.employee_attribute_versions
            .where("data -> 'attribute_type' = 'File' AND data -> 'id' = '#{file_id}'")
            .first
        end
      end
    end
  end
end
