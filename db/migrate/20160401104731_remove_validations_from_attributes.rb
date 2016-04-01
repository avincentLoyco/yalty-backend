
class RemoveValidationsFromAttributes < ActiveRecord::Migration
  def change

    def up
      Employee::AttributeDefinition
        .where(name: ['contract_type', 'occupation_rate'])
        .each do |attribute|
          attribute.validation.delete('presence')
          attribute.save
      end
    end

    def down
      Employee::AttributeDefinition
        .where(name: ['contract_type', 'occupation_rate'])
        .each do |attribute|
          attribute.validation['presence'] = true
          attribute.save
      end
    end
  end
end
