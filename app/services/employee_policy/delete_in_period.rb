module EmployeePolicy
  #================================================================================================
  # DeleteInPeriod class
  #================================================================================================
  # Deletes selected employee_join_tables in period
  #
  # Receives params:
  # - period_to_delete - period in which employee join tables will be removed
  # - join_table_types - array that specifies which employee join tables will be removed
  #                      eg. ["employee_working_places", "employee_time_off_policies"]
  # - employee         - if passed -> deletes employee join tables for passed employee
  #                      if not passed -> deletes employee join tables for account
  # - reset            - bool flag - decides if deleted employee join tables are reset type or not
  #                      if not passed it deletes all
  #================================================================================================

  class DeleteInPeriod
    JOIN_TABLE_MODULE_NAME = {
      "employee_working_places" => "WorkingPlace",
      "employee_presence_policies" => "Presence",
      "employee_time_off_policies" => "TimeOff",
    }.freeze
    RESET = { true => :with_reset, false => :not_reset }.freeze

    pattr_initialize [:period_to_delete!, :join_table_types, :employee, :reset]

    def self.call(period_to_delete:, join_table_types: nil, employee: nil, reset: nil)
      new(
        period_to_delete: period_to_delete,
        join_table_types: join_table_types,
        employee: employee,
        reset: reset
      ).call
    end

    def call
      return [] if join_table_types.nil?
      join_table_types.flat_map do |join_table_type|
        find_join_table_in_period(JOIN_TABLE_MODULE_NAME[join_table_type]).each(&:delete)
      end
    end

    private

    def find_join_table_in_period(module_name)
      join_tables =
        "EmployeePolicy::#{module_name}::FindInPeriod".constantize.call(
          period_to_search: period_to_delete,
          employee: employee
        )

      @reset.nil? ? join_tables : join_tables.send(RESET[@reset])
    end
  end
end
