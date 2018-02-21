module Export
  class GenerateEmployeesJournal
    attr_reader :account, :journal_since, :journal_timestamp, :journal_path

    EMPLOYEES_JOURNAL_COLUMNS = %w(
      account_uuid employee_uuid event_uuid event_name event_effective_at event_updated_at
      attribute_name attribute_value
    ).freeze

    def initialize(account, journal_since, journal_timestamp, base_path)
      @account = account
      @journal_since = journal_since
      @journal_timestamp = journal_timestamp
      @journal_path = generate_journal_path(base_path)
    end

    def call
      return unless events_since_last_export.exists?
      FileUtils.touch(journal_path)
      create_csv
      journal_path
    end

    private

    def create_csv
      CSV.open(journal_path, "wb") do |csv|
        csv << EMPLOYEES_JOURNAL_COLUMNS

        events_since_last_export.each do |event|
          ordered_versions = event.employee_attribute_versions
                                  .joins(:attribute_definition)
                                  .order("employee_attribute_definitions.name ASC")

          ordered_versions.each do |attribute_version|
            if attribute_version.value.is_a?(Enumerable)
              attribute_version.value.sort_by(&:first).each do |attribute|
                attribute_name = "#{attribute_version.attribute_name}_#{attribute.first}"
                csv << basic_row(event) + [attribute_name, attribute.second]
              end
            else
              csv << basic_row(event) + [attribute_version.attribute_name, attribute_version.value]
            end
          end
        end
      end
    end

    def basic_row(event)
      [
        account.id,
        event.employee_id,
        event.id,
        event.event_type,
        event.effective_at.strftime("%d-%m-%Y"),
        event.updated_at.strftime("%d-%m-%YT%H:%M:%S")
      ]
    end

    def generate_journal_path(base_path)
      filename = "#{account.id}-#{journal_timestamp.strftime("%Y-%m-%dT%H:%M:%S")}.csv"
      Pathname.new(base_path).join(filename)
    end

    def events_since_last_export
      @events_since_last_export ||= account.employee_events
                                           .where(events_where_sql)
                                           .order(:employee_id, :updated_at, :created_at, :id)
    end

    def events_where_sql
      return scheduled_export_sql if account.last_employee_journal_export.present?
      first_export_sql
    end

    def first_export_sql
      ["employee_events.updated_at < ?::timestamp", journal_timestamp]
    end

    def scheduled_export_sql
      [
        "employee_events.updated_at >= ?::timestamp AND employee_events.updated_at < ?::timestamp",
        journal_since,
        journal_timestamp
      ]
    end
  end
end
