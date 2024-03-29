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
      name.gsub(/^.+::/, "")
    end

    def attribute_type
      self.class.attribute_type
    end

    def present?
      attributes.values.any?
    end

    def validate_presence(additional_validation)
      except_type = attributes.except(:attribute_type, *optional_attributes)
      return if additional_validation.try(:[], "allow_nil").eql?(true) &&
          except_type.values.compact.empty?
      return if except_type.values.all?(&:present?)
      except_type.each do |k, v|
        errors.add(k, "can't be blank") unless v.present?
      end
    end

    def validate_inclusion(_additional_validation)
      allowed_values.map do |field, allowed|
        next if self[field].blank? || allowed.include?(self[field])
        errors.add(field, "value not allowed")
      end
    end

    def validate_country_code(_additional_validation)
      except_type = attributes.except(:attribute_type)
      return if except_type.values.first.blank? ||
          ISO3166::Country.codes.include?(except_type.values.first)
      errors.add("nationality", "country code invalid")
    end

    def validate_state_code(_additional_validation)
      except_type = attributes.except(:attribute_type)
      return if except_type.values.first.blank? ||
          ISO3166::Country.new(:ch).states.keys.include?(except_type.values.first)
      errors.add("state", "state code invalid")
    end

    def optional_attributes
      []
    end

    def allowed_values
      {}
    end
  end
end
