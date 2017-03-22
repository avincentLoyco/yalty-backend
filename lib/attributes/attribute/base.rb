module Attribute
  class Base
    include Virtus.model(coerce: false)
    include ActiveModel::Validations

    attribute :attribute_type

    def self.attribute_types
      @attribute_types ||= Attribute::Base.descendants.map do |descendant|
        descendant.to_s.demodulize
      end
    end

    def self.attribute_type
      name.gsub(/^.+::/, '')
    end

    def attribute_type
      self.class.attribute_type
    end

    def validate_presence
      except_type = attributes.except(:attribute_type, *optional_attributes)
      return unless except_type.values.size != except_type.values.compact.size
      except_type.each do |k, v|
        errors.add(k, "can't be blank") unless v
      end
    end

    def validate_inclusion
      allowed_values.map do |field, allowed|
        next if self[field].blank? || allowed.include?(self[field])
        errors.add(field, 'value not allowed')
      end
    end

    def optional_attributes
      []
    end

    def allowed_values
      {}
    end
  end
end
