module Export
  class GenerateSpreadsheets
    attr_reader :account, :archive_dir_path

    def initialize(account, archive_dir_path)
      @account          = account
      @archive_dir_path = archive_dir_path
    end

    def call
      GenerateEmployeesSpreadsheet.new(account, archive_dir_path).call
      GenerateWorkingHoursSpreadsheet.new(account, archive_dir_path).call
      GenerateTimeOffSpreadsheet.new(account, archive_dir_path).call
    end
  end
end
