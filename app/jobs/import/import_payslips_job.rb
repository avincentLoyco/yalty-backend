module Import
  class ImportPayslipsJob < ActiveJob::Base
    queue_as :import

    def perform(payslip_path)
      return unless ::Import::ImportAndAssignPayslips.enable?

      employee, import_date = payslip_path
        .scan(/([^\/]+?)-(\d+-\d+-\d+)\.pdf$/).flatten
        .tap do |values|
        values[0] = Employee.find(values[0])
        values[1] = Date.parse(values[1])
      end

      Dir.mktmpdir(employee.id) do |tmp_dir_path|
        ::Import::ImportAndAssignPayslips.new(employee, tmp_dir_path, import_date).call
      end
    end
  end
end
