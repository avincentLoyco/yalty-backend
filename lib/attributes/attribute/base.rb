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
      except_type = attributes.except(:attribute_type)
      return unless except_type.values.size != except_type.values.compact.size
      except_type.each do |k, v|
        errors.add(k, "can't be blank") unless v
      end
    end
  end
end
