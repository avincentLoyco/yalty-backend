class PrepareEmployeeBalancesToUpdate
  attr_reader :resource, :options, :balances_to_update_ids

  class << self
    def call(resource, options = {})
      new(resource, options).call
    end
  end

  def initialize(resource, options = {})
    @resource = resource
    @options = options
  end

  def call
    @balances_to_update_ids = FindEmployeeBalancesToUpdate.new(resource, options).call
    update_balances_processed_flag
    update_time_off_processed_flag
  end

  private

  def update_balances_processed_flag
    Employee::Balance.where(id: balances_to_update_ids).update_all(being_processed: true)
  end

  def update_time_off_processed_flag
    return unless resource.time_off.present?
    resource.time_off.update(being_processed: true) unless resource.time_off.destroyed?
  end
end
