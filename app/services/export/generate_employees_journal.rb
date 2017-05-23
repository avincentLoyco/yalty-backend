module Export
  class GenerateEmployeesJournal
    attr_reader :account, :dir_path, :journal_timestamp, :journal_path

    EMPLOYEES_JOURNAL_COLUMNS = %w(
      account_uuid employee_uuid event_uuid event_name event_effective_at event_updated_at
      attribute_name attribute_value
    ).freeze

    def initialize(account, dir_path)
      @account  = account
      @dir_path = dir_path
      @journal_timestamp = Time.zone.now
      @journal_path = generate_journal_path
    end

    def call
      FileUtils.touch(journal_path)
      create_csv
      account.update!(last_employee_journal_export: journal_timestamp)
      journal_path
    end

    private

    def create_csv
      CSV.open(journal_path, 'wb') do |csv|
        csv << EMPLOYEES_JOURNAL_COLUMNS

        events_since_last_export.each do |event|
          event.employee_attribute_versions.each do |attribute_version|
            if attribute_version.value.is_a?(Enumerable)
              attribute_version.value.each do |attribute|
                csv << basic_row(event) + [attribute.first.to_s, attribute.second]
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
        event.effective_at.strftime('%d.%m.%Y'),
        event.updated_at.strftime('%d.%m.%Y %H:%M')
      ]
    end

    def generate_journal_path
      filename = "#{account.id}-#{journal_timestamp.strftime('%Y-%m-%dT%T')}.csv"
      Pathname.new(dir_path).join(filename)
    end

    def events_since_last_export
      account.employee_events.where(events_where_sql).order(:employee_id).order(:updated_at)
    end

    def events_where_sql
      return scheduled_export_sql if account.last_employee_journal_export.present?
      first_export_sql
    end

    def first_export_sql
      ['employee_events.updated_at < ?::timestamp', journal_timestamp]
    end

    def scheduled_export_sql
      [
        'employee_events.updated_at >= ?::timestamp AND employee_events.updated_at < ?::timestamp',
        account.last_employee_journal_export,
        journal_timestamp
      ]
    end
  end
end
