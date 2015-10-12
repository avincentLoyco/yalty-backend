class EmployeeAttributeDefinitionRepresenter < BaseRepresenter
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
