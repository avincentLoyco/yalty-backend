module AttributeSerializer
  def self.dump(data)
    data.to_hash
  end

  def self.load(data)
    AttributeSerializer::Proxy.new(data)
  end

  class Proxy
    attr_reader :attribute_type

    def initialize(data)
      @data = data || {}
      @attribute_type = @data[:attribute_type] || @data['attribute_type']
    end

    def attribute_type=(attribute_type)
      @attribute_type ||= attribute_type
    end

    def to_hash
      (attribute_model || {}).to_hash
    end

    private

    def attribute_model
      if attribute_type.present?
        @attribute_model ||= ::Attribute.const_get(attribute_type).new(@data)
      end
    end

    def method_missing(meth, *args)
      if attribute_model
        attribute_model.send(meth, *args)
      else
        super
      end
    end
  end
end
