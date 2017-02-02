module API
  module V1
    class FileStorageTokensController < ApplicationController
      include TokensSchemas

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          file_not_found!(attributes[:file_id])
          version_doesnt_exist!(attributes[:version], attributes[:file_id])
          attr_version = find_attribute_version(attributes[:file_id])
          wrong_duration!(attr_version, attributes[:duration])
          authorize! :create, :tokens, attributes[:file_id], attr_version
          render json: SaveFileStorageTokenToRedis.new(attributes, attr_version).call, status: 201
        end
      end

      private

      def file_not_found!(file_id)
        return unless file_id.present? && !EmployeeFile.exists?(id: file_id)
        raise ActiveRecord::RecordNotFound
      end

      def version_doesnt_exist!(version, id)
        return unless version.present? && id.present? && !EmployeeFile.find(id).file.exists?(version)
        message = { version: 'Requested version of the file does not exist' }
        raise InvalidParamTypeError.new(version, message)
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

      def find_attribute_version(file_id)
        return unless file_id.present?
        Account
          .current.employee_attribute_versions
          .where("data -> 'attribute_type' = 'File' AND data -> 'id' = '#{file_id}'")
          .first
      end
    end
  end
end
