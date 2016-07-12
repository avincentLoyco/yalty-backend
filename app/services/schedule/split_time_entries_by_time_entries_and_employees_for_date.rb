class SplitTimeEntriesByTimeEntriesAndEmployeesForDate

  # @param time_entries_to_split
  #   [Array<Hash{start_time => String, end_time => String, employee => Employee}>]
  # @param time_entries_to_split
  #   [ Hash {
  #       Employee_id => Array<
  #         Hash{ start_time => string, end_time => String, employee => Employee }
  #        >
  #     }
  #   ]
  def initialize(
    time_entries_to_split,
    time_entries_to_base_the_split,
    time_entries_to_split_type,
    without_type = false
  )
    @time_entries_to_split = time_entries_to_split
    @time_entries_to_base_the_split = time_entries_to_base_the_split.with_indifferent_access
    @time_entries_to_split_type = time_entries_to_split_type
    @without_type = without_type
  end

  def call
    employees_hash = {}
    @time_entries_to_split.each do |time_entry_hash|
      time_entry = time_entry_hash.with_indifferent_access
      employee_id = time_entry[:employee_id]
      employees_hash[employee_id] ||= []
      employees_time_entries_to_split = @time_entries_to_base_the_split[employee_id]
      employees_time_entries_to_split ||= []
      employees_hash[employee_id] +=
        SplitTimeEntryByTimeEntries.new(
          time_entry,
          employees_time_entries_to_split
        ).call
    end
    format_time_entries(employees_hash)
  end

  private

  def format_time_entries(employee_hash_with_time_entries_in_time_format)
    hash_response = {}
    employee_hash_with_time_entries_in_time_format.each do |employee_id, time_entries_in_time_format|
      hash_response[employee_id.to_sym] =
        time_entries_in_time_format.map do |time_entry|
          formatted_entry = {
            start_time: time_entry.first.strftime('%H:%M:%S'),
            end_time: time_entry.last.strftime('%H:%M:%S')
          }
          formatted_entry[:type] = @time_entries_to_split_type unless @without_type
          formatted_entry
        end
    end
    hash_response
  end
end
