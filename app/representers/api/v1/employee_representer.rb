module Api::V1
  class EmployeeRepresenter < BaseRepresenter
    attr_reader :resource

    def complete
      {
        hiring_status: resource.can_be_hired?
      }
        .merge(basic)
        .merge(employee_data)
        .merge(relationships)
    end

    def employee_data
      {
        hired_date: resource.hired_date,
        contract_end_date: resource.contract_end_date,
        civil_status: resource.civil_status_for,
        civil_status_date: resource.civil_status_date_for
      }
    end

    def relationships
      {
        employee_attributes: employee_attributes_json,
        working_place: working_place_json,
        active_presence_policy: active_presence_policy_json
      }
    end

    def employee_attributes_json
      employee_attributes.map do |attribute|
        EmployeeAttributeRepresenter.new(attribute).complete
      end
    end

    def working_place_json
      return {} unless active_employee_working_place.present?
      EmployeeWorkingPlaceRepresenter.new(active_employee_working_place).working_place_json
    end

    def employee_attributes
      date = resource.hired_date <= Time.zone.today ? Time.zone.today : resource.hired_date
      FullEmployeeAttributesList.new(resource.account.id, resource.id, date).call
    end

    def active_employee_working_place
      @active_employee_working_place ||=
        related_resources(EmployeeWorkingPlace, nil, resource.id).first
      return if @active_employee_working_place&.related_resource&.reset?
      @active_employee_working_place
    end

    def active_presence_policy_json
      active_presence_policy = resource.active_presence_policy_at
      return {} unless active_presence_policy.present?

      {
        id: active_presence_policy.id,
        type: active_presence_policy.class.name.underscore,
        standard_day_duration: active_presence_policy.standard_day_duration
      }
    end
  end
end
