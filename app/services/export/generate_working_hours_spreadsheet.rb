module Export
  class GenerateWorkingHoursSpreadsheet
    attr_reader :account, :archive_dir_path

    DEFAULT_WORKING_HOURS_COLUMNS = ['Employee UUID', 'Date', 'Comment'].freeze

    def initialize(account, archive_dir_path)
      @account          = account
      @archive_dir_path = archive_dir_path
    end

    def call
      FileUtils.touch("#{archive_dir_path}/working_hours.csv")
      working_times = RegisteredWorkingTime
                      .where(employee_id: account.employees.pluck(:id))
                      .order(:date, :employee_id)

      max_time_entries_count = working_times.pluck(:time_entries).map(&:size).max.to_i

      columns = DEFAULT_WORKING_HOURS_COLUMNS
      columns += (1..max_time_entries_count).map { |number| "Timestamp #{number}" }

      CSV.open("#{archive_dir_path}/working_hours.csv", 'wb') do |working_times_csv|
        working_times_csv << columns

        working_times.each do |record|
          row = [record.employee_id, record.date.strftime('%d.%m.%Y'), record.comment]
          row += sorted_time_entries(record.time_entries).map do |time_entry|
            "#{time_entry['start_time']} - #{time_entry['end_time']}"
          end
          working_times_csv << row
        end
      end
    end

    def sorted_time_entries(time_entries)
      time_entries.sort_by { |time_entry| time_entry['start_time'] }
    end
  end
end
