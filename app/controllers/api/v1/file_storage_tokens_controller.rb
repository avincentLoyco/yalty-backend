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
          render json: SaveFileStorageTokenToRedis.new(attributes).call, status: :created
        end
      end

      private

      def file_not_found!(file_id)
        return unless file_id.present? && !GenericFile.exists?(id: file_id)
        raise ActiveRecord::RecordNotFound
      end

      def version_doesnt_exist!(version, file_id)
        return unless version.present? && !GenericFile.find(file_id).file.exists?(version)
        raise(
          CustomError,
          type: controller_name,
          field: "version",
          messages: ["Requested version of the file does not exist"],
          codes: ["version.requested_version_of_the_file_does_not_exist"]
        )
      end

      def wrong_duration!(attr_version, duration)
        return unless attr_version.present? && incorrect_duration?(attr_version, duration)
        raise(
          CustomError,
          type: controller_name,
          field: "duration",
          messages: ["Requested longterm token when not allowed"],
          codes: ["duration.requested_longterm_token_when_not_allowed"]
        )
      end

      def incorrect_duration?(attr_version, duration)
        duration.present? && duration.eql?("longterm") &&
          !attr_version.attribute_definition.long_token_allowed
      end

      def find_attribute_version(file_id)
        return unless file_id.present?
        Account
          .current.employee_attribute_versions
          .includes(:attribute_definition)
          .where("data -> 'attribute_type' = 'File' AND data -> 'id' = ?", file_id)
          .first
      end
    end
  end
end
