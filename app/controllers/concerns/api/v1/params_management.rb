require 'active_support/concern'

module API
  module V1
    module ParamsManagement
      extend ActiveSupport::Concern

      private

      def setup_params
        params.deep_transform_keys! { |key| unformat_key(key) }
      end

      def verify_type(type, resource_klass)
        if type.nil?
          fail JSONAPI::Exceptions::ParameterMissing, :type
        elsif unformat_key(type).to_sym != resource_klass._type
          fail JSONAPI::Exceptions::InvalidResource, type
        end
      end

      def verify_entity_uniqueness(id, entity_klass)
        return if id.present? && !entity_klass.where(id: id).exists?

        fail JSONAPI::Exceptions::EntityAlreadyExists, id
      end

      # If data is an array, verify if it have only one
      # item and return it. If data is not an array, just
      # return original value
      def parse_unique_data(data)
        if data.is_a?(Array) && data.size != 1
          fail JSONAP::Exceptions::InvalidLinksObject
        end

        data.is_a?(Array) ? data.first : data
      end

      def unformat_key(key)
        unformatted_key = key_formatter.unformat(key)
        unformatted_key.nil? ? nil : unformatted_key.to_sym
      end
    end
  end
end
