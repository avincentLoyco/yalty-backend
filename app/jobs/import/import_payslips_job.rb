module Import
  class ImportPayslipsJob < ActiveJob::Base
    queue_as :import

    class JobWrapper < CustomJobAdapter::JobWrapper
      sidekiq_options unique: :until_executed, unique_args: ->(args) { args.first["arguments"] }
    end

    def perform(payslip_path)
      return unless ::Import::ImportAndAssignPayslips.enable?

      import_date, employee =
        payslip_path
        .scan(%r{(\d{8})_([^/]+?)\.pdf$}).flatten
        .tap do |values|
          values[0] = Date.parse(values[0])
          values[1] = Employee.find(values[1])
        end

      Dir.mktmpdir(employee.id) do |tmp_dir_path|
        ::Import::ImportAndAssignPayslips.new(employee, tmp_dir_path, import_date).call
      end
    end
  end
end
