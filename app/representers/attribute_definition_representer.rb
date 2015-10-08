class AttributeDefinitionRepresenter < BaseRepresenter
  attr_reader :resource

  def initialize(definition)
    @resource = definition
  end

  def complete
    {
      name:           resource.name,
      label:          resource.label,
      attribute_type: resource.attribute_type,
      system:         resource.system,
    }
    .merge(basic)
  end
end
