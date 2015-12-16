module ValuesRules
  def gate_rules(attribute_name)
    allowed_attributes = "Attribute::#{attribute_name.classify}".constantize.new.attributes.keys
    Gate.rules do
      allowed_attributes.each do |attribute|
        optional attribute
      end
    end
  end
end
