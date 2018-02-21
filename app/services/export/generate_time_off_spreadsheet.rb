module Export
  class GenerateTimeOffSpreadsheet
    attr_reader :account, :archive_dir_path

    DEFAULT_TIME_OFFS_COLUMNS = ["Employee UUID", "Category", "From", "To"].freeze

    def initialize(account, archive_dir_path)
      @account          = account
      @archive_dir_path = archive_dir_path
    end

    def call
      FileUtils.touch("#{archive_dir_path}/time_offs.csv")

      CSV.open("#{archive_dir_path}/time_offs.csv", "wb") do |time_offs_csv|
        time_offs_csv << DEFAULT_TIME_OFFS_COLUMNS

        account.time_offs.order(:start_time, :employee_id).each do |time_off|
          time_offs_csv << [
            time_off.employee_id,
            time_off.time_off_category.name,
            time_off.start_time.strftime("%Y.%m.%d %T"),
            time_off.end_time.strftime("%Y.%m.%d %T")
          ]
        end
      end
    end
  end
end
