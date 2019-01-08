module Api::V1
  class EmployeeRepresenter < BaseRepresenter
    attr_reader :resource

    def complete
      {
        hiring_status: resource.can_be_hired?,
        is_old_employee: resource.hired_before_migration?,
        role: resource.user&.role,
      }
        .merge(basic)
        .merge(employee_data)
        .merge(relationships)
    end

    def fullname
      basic.merge(
        fullname: resource.fullname,
        account_user_id: resource.account_user_id
      )
    end

    def employee_data
      {
        hired_date: resource.hired_date,
        manager_id: resource.manager_id,
        contract_end_date: resource.contract_end_date,
        civil_status: resource.civil_status_for,
        civil_status_date: resource.civil_status_date_for,
        time_off_policy_amount: time_off_policy_amount,
      }
    end

    def relationships
      {
        employee_attributes: employee_attributes_json,
        working_place: working_place_json,
        active_presence_policy: active_presence_policy_json,
        active_vacation_policy: active_vacation_policy_json,
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
        standard_day_duration: full_time_standard_day_duration,
      }
    end

    def active_vacation_policy_json
      return {} unless active_vacation_policy.present?
      {
        id: active_vacation_policy.time_off_policy.id,
        assignation_id: active_vacation_policy.id,
        type: active_vacation_policy.time_off_policy.class.name.underscore,
        assignation_type: active_vacation_policy.class.name.underscore,
        effective_at: active_vacation_policy.effective_at,
        effective_till: active_vacation_policy.effective_till,
        employee_balance: employee_balance_json(active_vacation_policy),
      }
    end

    def employee_balance_json(active_vacation_policy)
      return unless active_vacation_policy.policy_assignation_balance.present?
      EmployeeBalanceRepresenter.new(active_vacation_policy.policy_assignation_balance).complete
    end

    def vacation_category
      resource.account.time_off_categories.vacation.first
    end

    def active_vacation_policy
      resource.active_policy_in_category_at_date(vacation_category&.id)
    end

    def full_time_standard_day_duration
      resource.account.standard_day_duration
    end

    def time_off_policy_amount
      return unless active_vacation_policy.present? && full_time_standard_day_duration.present?
      active_vacation_policy.time_off_policy.amount / full_time_standard_day_duration
    end
  end
end
