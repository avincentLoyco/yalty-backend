module Import
  class ImportAndAssignPayslips
    attr_reader :employee, :import_date, :payslip_filename, :import_path, :event

    def initialize(employee, tmp_path, import_date = Time.zone.now)
      @employee = employee
      @import_date = import_date
      @payslip_filename = "#{import_date.strftime('%Y%m%d')}_#{employee.id}.pdf"
      @import_path = Pathname.new(tmp_path).join(payslip_filename)
      @event = employee.events.find_by(event_type: 'salary_paid', effective_at: import_date.to_date)
    end

    def call
      return unless enable?

      Net::SFTP.start(
        ENV['LOYCO_SSH_HOST'],
        ENV['LOYCO_SSH_USER'],
        keys: [ENV['LOYCO_SSH_KEY_PATH']]
      ) do |sftp|
        sftp.dir.glob(ENV['LOYCO_SSH_IMPORT_PAYSLIPS_PATH'], "**/#{payslip_filename}") do |entry|
          payslip_path = Pathname.new(ENV['LOYCO_SSH_IMPORT_PAYSLIPS_PATH']).join(entry.name)
          File.open(import_path, mode: 'wb') do |file|
            sftp.download!(payslip_path, file)
          end

          value = attribute_version_values_from(
            GenericFile.create!(file: File.open(import_path), fileable_type: 'EmployeeFile')
          )

          if event.present?
            event.employee_attribute_versions.last.update!(value: value)
          else
            create_salary_paid_event(value)
          end

          sftp.remove!(payslip_path)
          break
        end
      end
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

    private

    def create_salary_paid_event(value)
      new_event = employee.events.new(event_type: 'salary_paid', effective_at: import_date)
      version = Employee::AttributeVersion.new(
        employee: employee, account: employee.account, value: value, attribute_name: 'salary_slip'
      )
      new_event.employee_attribute_versions = [version]
      new_event.save!
    end

    def attribute_version_values_from(payslip)
      {
        size: payslip.file_file_size,
        id: payslip.id,
        file_type: payslip.file_content_type
      }.merge(payslip.sha_sums)
    end
  end
end
