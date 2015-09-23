require 'active_support/concern'

module API
  module V1
    module ParamsManagement
      extend ActiveSupport::Concern

      private

      def setup_params
        params.deep_transform_keys! {|key| unformat_key(key) }
      end

      def verify_type(type, resource_klass)
        if type.nil?
          fail JSONAPI::Exceptions::ParameterMissing.new(:type)
        elsif unformat_key(type).to_sym != resource_klass._type
          fail JSONAPI::Exceptions::InvalidResource.new(type)
        end
      end

      def verify_entity_uniqueness(id, entity_klass)
        if id.present? && entity_klass.where(id: id).exists?
          fail JSONAPI::Exceptions::EntityAlreadyExists.new(id)
        end
      end

      def unformat_key(key)
        unformatted_key = key_formatter.unformat(key)
        unformatted_key.nil? ? nil : unformatted_key.to_sym
      end
    end
  end
end
