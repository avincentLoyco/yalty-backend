module AttributeSerializer
  extend ActiveSupport::Concern

  class_methods do
    def serialized_attributes(&block)
      if self.const_defined?('DataSerializer')
        klass = self.const_get('DataSerializer')
        klass.class_eval(&block) if block
      else
        klass = Class.new(AttributeSerializer::Base, &block)
        self.const_set('DataSerializer', klass)
      end

      klass.attribute_set.each do |attribute|
        self.delegate attribute.name, "#{attribute.name}=", to: :data
      end

      self.serialize :data, klass
    end
  end

  class Base
    include Virtus.model

    def self.dump(data)
      data.to_hash
    end

    def self.load(data)
      new(data)
    end
  end
end
