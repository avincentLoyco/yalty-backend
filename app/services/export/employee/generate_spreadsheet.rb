module Export
  module Employee
    class GenerateSpreadsheet
      pattr_initialize :account, :archive_dir_path

      def self.call(account, archive_dir_path)
        new(account, archive_dir_path).call
      end

      def call
        FileUtils.touch(file_path)

        attributes = Export::Account::DataBuilder.call(account)
        generated_columns = Export::Employee::SpreadsheetColumnBuilder.call(attributes)
        generated_data =
          Export::Employee::SpreadsheetDataBuilder.call(attributes, generated_columns)

        CSV.open(file_path, "wb") do |employee_csv|
          employee_csv << headers(generated_columns)
          normalised_data(generated_data).each { |row| employee_csv << row }
        end
      end

      private

      def file_path
        "#{archive_dir_path}/employees.csv"
      end

      def headers(columns)
        columns.values.map do
          |attribute| attribute.is_a?(Hash) ? attribute.values : attribute
        end.flatten
      end

      def normalised_data(data)
        data.map(&:flatten).map { |employee_data| employee_data.map(&method(:normalise_date)) }
      end

      def normalise_date(value)
        return if value.nil?

        begin
          date = Date.parse(value)
          date.strftime("%d.%m.%Y")
        rescue ArgumentError
          value
        end
      end
    end
  end
end
