class UpdateEvent
  include API::V1::Exceptions
  attr_reader :employee_params, :attributes_params, :event_params, :versions, :event, :employee,
    :updated_assignations, :old_effective_at, :presence_policy_id, :time_off_policy_days, :params

  def initialize(event, params)
    @versions             = []
    @employee_params      = params[:employee].tap { |attr| attr.delete(:employee_attributes) }
    @attributes_params    = params[:employee_attributes].to_a
    @presence_policy_id   = params[:presence_policy_id]
    @time_off_policy_days = params[:time_off_policy_amount]
    @event_params         = build_event_params(params)
    @updated_assignations = {}
    @event                = event
    @old_effective_at     = event.effective_at
    @params               = params
  end

  def call
    ActiveRecord::Base.transaction do
      find_and_update_event
      find_employee
      assign_manager
      update_employee_join_tables
      manage_versions
      save!
    end
    event.tap { handle_hired_or_work_contract_event }
    event.tap { handle_contract_end }
  end

  private

  def assign_manager
    return unless employee_params.key?(:manager_id)
    AssignManager.call(employee: @employee, manager_id: employee_params[:manager_id])
  end

  def handle_hired_or_work_contract_event
    return unless event.event_type.in?(%w(hired work_contract))

    validate_time_off_policy_days_presence
    validate_presence_policy_presence

    time_off_policy_amount = time_off_policy_days * current_account.standard_day_duration

    if presence_policy_id.eql?(event.employee_presence_policy&.presence_policy&.id)
      EmployeePolicy::Presence::Update.call(update_presence_policy_params)
    else
      EmployeePolicy::Presence::Destroy.call(event.employee_presence_policy)
      EmployeePolicy::Presence::Create.call(create_presence_policy_params)
    end

    validate_matching_occupation_rate
    UpdateEtopForEvent.new(event.id, time_off_policy_amount, old_effective_at).call
  end

  def handle_contract_end
    return unless event.event_type.eql?("contract_end") && old_effective_at != event.effective_at
    ContractEnds::Update.call(
      employee: employee,
      new_contract_end_date: event.effective_at,
      old_contract_end_date: old_effective_at,
      eoc_event_id: event.id
    )
  end

  def build_event_params(params)
    params.tap do |attr|
      attr.delete(:employee)
      attr.delete(:employee_attributes)
      attr.delete(:presence_policy_id)
      attr.delete(:time_off_policy_amount)
    end
  end

  def update_presence_policy_params
    { id: event.employee_presence_policy.id, effective_at: params[:effective_at] }
  end

  def create_presence_policy_params
    { event_id: event.id, presence_policy_id: presence_policy_id }
  end

  def find_employee
    @employee = current_account.employees.find(employee_params[:id])
  end

  def find_and_update_event
    event.attributes = event_params.except(:presence_policy_id, :event)
  end

  def update_employee_join_tables
    return if event.event_type != "hired"
    @updated_assignations =
      HandleMapOfJoinTablesToNewHiredDate.new(
        employee, event_params[:effective_at], event.effective_at_was
      ).call
  end

  def manage_versions
    attributes_params.each do |attribute|
      if attribute[:id].present?
        update_version(attribute)
      else
        new_version(attribute)
      end
    end
    remove_absent_versions
    event.employee_attribute_versions = versions + not_editable_versions
  end

  def update_version(attribute)
    version = event.employee_attribute_versions.find(attribute[:id])
    version.attribute_definition = definition_for(attribute)
    version.value = FindValueForAttribute.new(attribute, version).call
    version.order = attribute[:order]
    @versions << version
  end

  def new_version(attribute)
    version = build_version(attribute)
    if version.attribute_definition_id.present?
      version.value = FindValueForAttribute.new(attribute, version).call
      version.multiple = version.attribute_definition.multiple
    end
    @versions << version
  end

  def build_version(version)
    event.employee_attribute_versions.new(
      employee: employee,
      attribute_definition: definition_for(version),
      order: version[:order]
    )
  end

  def definition_for(attribute)
    current_account.employee_attribute_definitions.find_by(name: attribute[:attribute_name])
  end

  def unique_attribute_versions?
    definition = versions.map do |version|
      version.attribute_definition_id unless version.multiple
    end.compact
    definition.size == definition.uniq.size
  end

  def remove_absent_versions
    editable_versions = find_editable_versions
    return unless editable_versions.size > versions.size
    versions_to_remove = editable_versions - versions
    versions_to_remove.map(&:destroy!)
  end

  def find_editable_versions
    event.employee_attribute_versions - not_editable_versions
  end

  def not_editable_versions
    return [] if Account::User.current.owner_or_administrator?
    Employee::AttributeVersion.not_editable.where(employee_event_id: event.id)
  end

  def attribute_version_valid?
    !event.employee_attribute_versions.map(&:valid?).include?(false)
  end

  def valid?
    employee.valid? && unique_attribute_versions? && attribute_version_valid?
  end

  def save!
    if unique_attribute_versions? && attribute_version_valid?
      employee.save!
      update_event_and_assignations
      event.employee_attribute_versions.each(&:save!)
      event
    else
      messages = {}
      unless unique_attribute_versions?
        messages = messages.merge(employee_attributes: ["Not unique"])
      end
      messages = messages.merge(attribute_versions_errors)

      raise InvalidResourcesError.new(event, messages)
    end
  end

  def update_event_and_assignations
    return event.save! unless event.event_type.eql?("hired")
    if event.effective_at.to_date < old_effective_at
      event.save!
      update_assignations_and_balances
      create_policy_additions_and_removals
    else
      update_assignations_and_balances
      event.save!
      update_contract_end
    end
    update_balances
  end

  def update_contract_end
    contract_end_for = employee.contract_end_for(old_effective_at)
    return unless contract_end_for.present? && contract_end_for + 1.day == old_effective_at
    ::ContractEnds::Update.call(
      employee: employee,
      new_contract_end_date: old_effective_at,
      old_contract_end_date: old_effective_at,
      eoc_event_id: event.id
    )
  end

  def update_assignations_and_balances
    return unless updated_assignations.present?
    updated_assignations[:join_tables].to_a.map(&:save!)
    updated_assignations[:employee_balances].to_a.map(&:save!)
    updated_assignations[:employee_balances].map do |balance|
      UpdateEmployeeBalance.new(balance).call
    end
  end

  def create_policy_additions_and_removals
    return unless updated_assignations.present?
    employee_time_off_policies =
      updated_assignations[:join_tables].select do |join_table|
        join_table.class.eql?(EmployeeTimeOffPolicy)
      end
    employee_time_off_policies.map do |policy|
      ManageEmployeeBalanceAdditions.new(policy, false).call
    end
  end

  def employee_working_place_errors
    return {} unless updated_working_place
    updated_working_place.errors.messages
  end

  def attribute_versions_errors
    errors = event.employee_attribute_versions.map do |attr|
      return {} unless attr.attribute_definition
      { attr.attribute_definition.name => attr.data.errors.messages.values }
    end
    errors.reduce({}, :merge).delete_if { |_key, value| value.empty? }
  end

  def update_balances
    return unless updated_assignations[:employee_balances].present?
    updated_assignations[:employee_balances].map do |balance|
      PrepareEmployeeBalancesToUpdate.new(balance, update_all: true).call
      ActiveRecord::Base.after_transaction do
        UpdateBalanceJob.perform_later(balance.id, update_all: true)
      end
    end
  end

  def validate_time_off_policy_days_presence
    return unless time_off_policy_days.nil?
    raise InvalidResourcesError.new(event, { time_off_policy_amount: ["not present"] })
  end

  def validate_presence_policy_presence
    return unless presence_policy_id.nil?
    raise InvalidResourcesError.new(event, { presence_policy: ["not present"] })
  end

  def validate_matching_occupation_rate
    return if presence_policy_occupation_rate.eql?(event_occupation_rate)
    raise InvalidResourcesError.new(event, { occupation_rate:
      ["Does not match Presence Policy's occupation rate"] })
  end

  def presence_policy_occupation_rate
    event.employee_presence_policy.presence_policy.occupation_rate
  end

  def event_occupation_rate
    event.attribute_value("occupation_rate").to_f
  end

  def current_account
    @account ||= event.account
  end
end
