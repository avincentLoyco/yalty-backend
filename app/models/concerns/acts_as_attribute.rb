require 'active_support/concern'

module ActsAsAttribute
  extend ActiveSupport::Concern

  included do
    belongs_to :attribute_definition,
      ->(attr) { readonly },
      class_name: 'Employee::AttributeDefinition',
      required: true

    serialize :data, AttributeSerializer

    validates :attribute_definition_id,
      uniqueness: { allow_nil: true, scope: [:employee] }

    after_initialize :set_attribute_definition
  end

  def attribute_type
    attribute_definition.try(:attribute_type)
  end

  def attribute_name
    attribute_definition.try(:name)
  end

  def attribute_name=(value)
    set_attribute_definition(value)
  end

  def value
    data.try(:value)
  end

  def value=(value)
    set_attribute_definition

    if value.is_a?(Hash)
      self.data = value.dup.merge(:attribute_type => data.attribute_type)
    else
      key = data.attributes.keys
        .select{|key| key.to_sym != :attribute_type }
        .first.to_sym

      self.data = {
        :attribute_type => data.attribute_type,
        key => value
      }
    end
  end

  private

  def set_attribute_definition(name = nil)
    if !attribute_definition.present?
      if account.nil?
        self.attribute_definition = nil
      else
        self.attribute_definition = account.employee_attribute_definitions
          .where(name: name)
          .readonly
          .first
      end
    end

    data.attribute_type = attribute_type
  end

  module AttributeSerializer
    def self.dump(data)
      data.to_hash
    end

    def self.load(data)
      AttributeProxy.new(data)
    end
  end

  class AttributeProxy
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

    def value
      value = to_hash.dup
      value.delete(:attribute_type) || value.delete('attribute_type')

      if value.keys.size > 1
        value
      else
        value.values.first
      end
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