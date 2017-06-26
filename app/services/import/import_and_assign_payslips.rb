module Import
  class ImportAndAssignPayslips
    attr_reader :employee, :import_path, :import_date

    def initialize(employee, import_path, import_date = Time.zone.now)
      @employee = employee
      @import_path = import_path
      @import_date = import_date
    end

    def call
      # download pay slip to tmp dir
      # connect to loyco SFTP
      # do a recursive search for a file <EMPLOYEE_UUID>-<MM>-<YYYY>.pdf
      # create or update salary_paid event for employee
      # remove pay slip from SFTP
    end

    def self.enable?
      [
        ENV['LOYCO_SSH_HOST'],
        ENV['LOYCO_SSH_USER'],
        ENV['LOYCO_SSH_KEY_PATH'],
        ENV['LOYCO_SSH_IMPORT_PAYSLIPS_PATH']
      ].all?(&:present?)
    end

    def enable?
      self.class.enable?
    end
  end
end
