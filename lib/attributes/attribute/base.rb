module Attribute
  class Base
    include Virtus.model(coerce: false)

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

    def self.ruby_types
      @ruby_types ||= Attribute::Base.descendants.map do |descendant|
        { descendant.name => descendant.ruby_type.constantize }
      end
    end

    def self.ruby_type
      'String'
    end
  end
end
