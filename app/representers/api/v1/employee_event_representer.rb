module Api::V1
  class EmployeeEventRepresenter < BaseRepresenter
    def complete
      {
        effective_at: resource.effective_at,
        event_type: resource.event_type,
        deletable: resource.can_destroy_event?,
        active: resource.can_edit_event?,
        presence_policy_id: presence_policy_id,
        time_off_policy_amount: time_off_policy_amount,
      }
        .merge(basic)
        .merge(relationship)
    end

    def relationship
      {
        employee: employee_json,
        employee_attributes: attribute_versions,
      }
    end

    def employee_json
      EmployeeRepresenter.new(resource.employee).basic
    end

    def presence_policy_id
      return unless resource.event_type.in?(%w(hired work_contract)) &&
          resource.employee_presence_policy.present?
      resource.employee_presence_policy.presence_policy_id
    end

    def time_off_policy_amount
      return unless resource.event_type.in?(%w(hired work_contract)) &&
          resource.employee_time_off_policy.present?

      standard_day_duration =
        resource.employee.account.presence_policies.full_time.standard_day_duration

      return if standard_day_duration.nil?
      resource.employee_time_off_policy.time_off_policy.amount / standard_day_duration
    end

    def attribute_versions
      attribute_versions = select_attributes
      attribute_versions.map do |attribute|
        EmployeeAttributeVersionRepresenter.new(attribute).complete
      end
    end

    def select_attributes
      if Account::User.current.try(:owner_or_administrator?) ||
          Account::User.current.try(:employee).try(:id) == resource.employee_id
        resource.employee_attribute_versions
      else
        resource.employee_attribute_versions.visible_for_other_employees
      end
    end
  end
end
