module Export
  class CreateArchiveZip
    def initialize(account)
      @account = account
    end

    def call
      Dir.mktmpdir(@account.subdomain) do |tmp_dir_path|
        archive_dir_path = generate_archive_dir_path(tmp_dir_path)
        employees_dir_path = Pathname.new(archive_dir_path).join('employees')
        FileUtils.mkdir_p(archive_dir_path)

        GenerateEmployeesSpreadsheet.new(@account, archive_dir_path).call
        GenerateWorkingHoursSpreadsheet.new(@account, archive_dir_path).call
        GenerateTimeOffSpreadsheet.new(@account, archive_dir_path).call

        copy_employees_files(employees_dir_path)
        zip_and_assign_archive(archive_dir_path)
      end
    end

    private

    def copy_employees_files(employees_dir_path)
      @account.employees.each do |employee|
        next if employee.files.empty?

        employee_dir_path = Pathname.new(employees_dir_path).join(employee.id, 'files')
        FileUtils.mkdir_p(employee_dir_path)

        employee.files.each do |employee_file|
          FileUtils.cp(employee_file.file.path, employee_dir_path)
        end
      end
    end

    def zip_and_assign_archive(archive_dir_path)
      archive_zip_path = archive_dir_path.to_s + '.zip'
      `
        cd "#{archive_dir_path}"
        zip -r -9 "#{archive_zip_path}" .
        cd -
      `
      zip_file = File.open(archive_zip_path)

      @account.transaction do
        @account.update!(archive_file: GenericFile.create!(file: zip_file))
      end

      zip_file.close
    end

    def generate_archive_dir_path(path)
      Pathname.new(path).join("archive-#{@account.subdomain}-#{Time.zone.today.strftime('%Y%m%d')}")
    end
  end
end
