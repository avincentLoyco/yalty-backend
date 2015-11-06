module Api::V1
  class EmployeeAttributeDefinitionRepresenter < BaseRepresenter
    def complete
      {
        name:           resource.name,
        label:          resource.label,
        attribute_type: resource.attribute_type,
        system:         resource.system,
        multiple:       resource.multiple
      }
        .merge(basic)
    end
  end
end
