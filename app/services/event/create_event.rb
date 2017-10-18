class CreateEvent
  include API::V1::Exceptions
  attr_reader :employee_params, :attributes_params, :event_params, :employee,
    :event, :versions, :presence_policy_id, :time_off_policy_days

  def initialize(params, employee_attributes_params)
    @employee             = nil
    @event                = nil
    @versions             = []
    @employee_params      = params[:employee]
    @attributes_params    = employee_attributes_params
    @presence_policy_id   = params[:presence_policy_id]
    @time_off_policy_days = params[:time_off_policy_amount]
    @event_params         = build_event_params(params)
  end

  def call
    ActiveRecord::Base.transaction do
      build_event
      find_or_build_employee
      build_versions
      save!
      event.tap { handle_hired_or_work_contract_event }
      event.tap { handle_contract_end }
    end
  end

  private

  def build_event_params(params)
    params.tap do |attr|
      attr.delete(:employee)
      attr.delete(:employee_attributes)
      attr.delete(:presence_policy_id)
      attr.delete(:time_off_policy_amount)
    end
  end

  def find_or_build_employee
    if employee_params.key?(:id)
      @employee = Account.current.employees.find(employee_params[:id])
    else
      @employee = Account.current.employees.new
      employee.events << [event]
    end

    event.employee = @employee
  end

  def build_event
    @event = Account.current.employee_events.new(event_params)
  end

  def build_versions
    attributes_params.each do |attribute|
      version = build_version(attribute)
      if version.attribute_definition_id.present?
        version.value = FindValueForAttribute.new(attribute, version).call
        version.multiple = version.attribute_definition.multiple
      end
      @versions << version
    end

    event.employee_attribute_versions = versions
  end

  def build_version(version)
    event.employee_attribute_versions.new(
      employee: employee,
      attribute_definition: definition_for(version),
      order: version[:order]
    )
  end

  def definition_for(attribute)
    Account.current.employee_attribute_definitions.find_by(name: attribute[:attribute_name])
  end

  def unique_attribute_versions?
    definition = event.employee_attribute_versions.map do |version|
      version.attribute_definition_id unless version.multiple
    end.compact

    definition.size == definition.uniq.size
  end

  def save!
    if event.valid? && employee.valid? && unique_attribute_versions?
      event.save!
      employee.save!

      event
    else
      messages = {}
      unless unique_attribute_versions?
        messages = messages.merge(employee_attributes: ['Not unique'])
      end
      messages = messages
                 .merge(event.errors.messages)
                 .merge(employee.errors.messages)
                 .merge(attribute_versions_errors)

      raise InvalidResourcesError.new(event, messages)
    end
  end

  def attribute_versions_errors
    errors = event.employee_attribute_versions.map do |attr|
      return {} unless attr.attribute_definition
      {
        attr.attribute_definition.name => attr.errors.messages
      }
    end
    errors.delete_if { |error| error.values.first.empty? }.reduce({}, :merge)
  end

  def handle_contract_end
    return unless event.event_type.eql?('contract_end')
    HandleContractEnd.new(employee, event.effective_at).call
  end

  def handle_hired_or_work_contract_event
    return unless event.event_type.in?(%w(hired work_contract)) &&
        time_off_policy_days.present? && presence_policy_id.present?
    presence_policy = PresencePolicy.find(presence_policy_id)
    time_off_policy_amount = time_off_policy_days * presence_policy.standard_day_duration
    HandleEppForEvent.new(event.id, presence_policy_id).call
    CreateEtopForEvent.new(event.id, time_off_policy_amount).call
  end
end
