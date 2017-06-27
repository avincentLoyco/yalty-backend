class MergeAllEventsInFirstOne < ActiveRecord::Migration
  def up
    Employee.all.each do |employee|
      hired = employee.events.hired.order('effective_at ASC').first

      employee.events.where.not(id: hired.id).order('effective_at ASC').all.each do |event|
        event.employee_attribute_versions.all.each do |attribute|
          puts "Merge attribute version #{attribute.id} in event #{hired.id}"

          hired_attr = hired.employee_attribute_versions
            .where(attribute_definition_id: attribute.attribute_definition_id)
            .first

          if hired_attr
            hired_attr.data = attribute.data.to_hash
            hired_attr.save!
            attribute.destroy!
          else
            attribute.employee_event_id = hired.id
            attribute.save!
          end
        end

        event.destroy!
      end
    end
  end

  def down
  end
end
