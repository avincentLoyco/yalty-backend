module Import
  class ImportPayslipsJob < ActiveJob::Base
    queue_as :export

    def perform(account)
      return unless ::Import::ImportAndAssignPayslips.enable?

      account.employees.each do |employee|
        Dir.mktmpdir(employee.email) do |tmp_dir_path|
          ::Import::ImportAndAssignPayslips.new(employee, tmp_dir_path).call
        end
      end
    end
  end
end
