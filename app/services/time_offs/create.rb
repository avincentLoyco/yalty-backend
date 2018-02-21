module TimeOffs
  class Create
    attr_reader :start_time, :end_time, :time_off_category_id, :employee_id

    def self.call(start_time, end_time, time_off_category_id, employee_id)
      new(start_time, end_time, time_off_category_id, employee_id).call
    end

    def initialize(start_time, end_time, time_off_category_id, employee_id)
      @start_time           = convert_time_to_utc(start_time)
      @end_time             = convert_time_to_utc(end_time)
      @time_off_category_id = time_off_category_id
      @employee_id          = employee_id
    end

    def call
      time_off = TimeOff.new(start_time: start_time,
                             end_time: end_time,
                             time_off_category_id: time_off_category_id,
                             employee_id: employee_id)

      ActiveRecord::Base.transaction do
        time_off.save! && create_new_employee_balance(time_off)
      end
    end

    def convert_time_to_utc(time)
      return if time.nil?
      time.to_s + "00:00"
    end

    private

    def create_new_employee_balance(time_off)
      account_id = Employee.find(employee_id).account.id

      CreateEmployeeBalance.new(
        time_off_category_id,
        employee_id,
        account_id,
        time_off_id: time_off.id,
        balance_type: "time_off",
        resource_amount: time_off.balance,
        manual_amount: 0,
        effective_at: time_off.end_time
      ).call
    end
  end
end
