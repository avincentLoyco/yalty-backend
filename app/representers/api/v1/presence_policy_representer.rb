module Api::V1
  class PresencePolicyRepresenter < BaseRepresenter
    def complete
      {
        name: resource.name,
        occupation_rate: resource.occupation_rate,
        standard_day_duration: resource.standard_day_duration,
        default_full_time: resource.default_full_time,
        active: resource.active,
        deletable: assigned_employees_json.empty?,
      }
        .merge(basic)
    end

    def with_relationships
      complete.merge(presence_days: presence_days_json)
              .merge(assigned_employees: assigned_employees_json)
    end

    def presence_days_json
      resource.presence_days.map do |attribute|
        PresenceDayRepresenter.new(attribute).complete
      end
    end

    def assigned_employees_json
      related_resources(EmployeePresencePolicy, resource.id).map do |employee_presence_policy|
        EmployeePresencePolicyRepresenter.new(employee_presence_policy).complete
      end
    end
  end
end
