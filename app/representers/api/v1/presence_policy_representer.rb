module Api::V1
  class PresencePolicyRepresenter < BaseRepresenter
    def complete
      {
        name: resource.name
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
      JoinTableWithEffectiveTill
        .new(EmployeePresencePolicy, current_user.account_id).call.map do |epp_hash|
          epp = EmployeePresencePolicy.new(epp_hash)
          EmployeePresencePolicyRepresenter.new(epp).complete
        end
    end
  end
end
