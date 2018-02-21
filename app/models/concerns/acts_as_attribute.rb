require "active_support/concern"

module ActsAsAttribute
  extend ActiveSupport::Concern

  PUBLIC_ATTRIBUTES_FOR_OTHERS = %w(
    firstname lastname language job_title start_date occupation_rate department
    manager professional_email professional_mobile cost_center department gender
    profile_picture
  ).freeze

  NOT_EDITABLE_ATTRIBUTES_FOR_EMPLOYEE = %w(
    annual_salary contract_type cost_center department exit_date hourly_salary job_title
    manager monthly_payments representation_fees start_date tax_source_code
    salary_slip salary_certificate contract
  ).freeze

  included do
    belongs_to :attribute_definition,
      -> { readonly },
      class_name: "Employee::AttributeDefinition",
      required: true

    serialize :data, AttributeSerializer

    validates :attribute_definition_id, presence: true
    validate :definition_validations, if: :model_and_validation_present?

    after_initialize :setup_attribute_definition
  end

  def attribute_type
    attribute_definition.try(:attribute_type)
  end

  def attribute_name
    attribute_definition.try(:name)
  end

  def attribute_key
    data.attributes.keys
        .find { |key| key.to_sym != :attribute_type }
        .to_sym
  end

  def attribute_name=(value)
    setup_attribute_definition(value)
  end

  def value
    data.try(:value)
  end

  def value=(value)
    setup_attribute_definition

    if value.is_a?(Hash)
      self.data = value.dup.merge(attribute_type: data.attribute_type)
    else
      self.data = {
        :attribute_type => data.attribute_type,
        attribute_key => value
      }
    end
  end

  private

  def definition_validations
    attribute_definition.validation.each do |k, v|
      validation_method = "validate_#{k}"
      return nil unless data.attribute_model.respond_to?(validation_method)
      data.attribute_model.send(validation_method, v)
    end
    map_errors
  end

  def model_and_validation_present?
    data.attribute_model && attribute_definition.try(:validation)
  end

  def map_errors
    data.attribute_model.errors.messages.each do |kv|
      errors.add(attribute_definition.name, kv.join(" - "))
    end
  end

  def setup_attribute_definition(name = nil)
    unless attribute_definition.present?
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
      @attribute_type = @data[:attribute_type] || @data["attribute_type"]
    end

    def attribute_type=(attribute_type)
      @attribute_type ||= attribute_type
    end

    def to_hash
      (attribute_model || {}).to_hash
    end

    def value
      value = to_hash.dup
      value.delete(:attribute_type) || value.delete("attribute_type")

      if value.keys.size > 1
        value
      else
        value.values.first
      end
    end

    def attribute_model
      return unless attribute_type.present?

      @attribute_model ||= ::Attribute.const_get(attribute_type).new(@data)
    end

    private

    def method_missing(meth, *args)
      if attribute_model
        attribute_model.send(meth, *args)
      else
        super
      end
    end
  end
end
