module TimeOffs
  class DeleteInPeriod
    pattr_initialize [:period_to_delete, :time_off_category_id, :employee]

    def self.call(period_to_delete:, time_off_category_id: nil, employee: nil)
      new(
        period_to_delete: period_to_delete,
        time_off_category_id: time_off_category_id,
        employee: employee
      ).call
    end

    def call
      time_offs_to_delete.each do |time_off|
        time_off.employee_balance&.destroy!
        time_off.destroy!
      end
    end

    private

    def time_offs_to_delete
      TimeOffs::FindInPeriod.call(
        period_to_search: period_to_delete,
        time_off_category_id: time_off_category_id,
        employee: employee
      )
    end
  end
end
