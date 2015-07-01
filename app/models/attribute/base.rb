module Attribute
  class Base
    include Virtus.model

    attribute :attribute_type

    def self.inherited(klass)
      super

      attribute_types << klass.attribute_type
    end

    def self.attribute_types
      @attribute_types ||= []
    end

    def self.attribute_type
      name.gsub(/^.+::/, '')
    end

    def attribute_type
      self.class.attribute_type
    end
  end
end
