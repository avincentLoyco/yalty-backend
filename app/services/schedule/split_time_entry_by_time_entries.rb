class SplitTimeEntryByTimeEntries
  def initialize(time_entry, time_entries)
    @time_entry = time_entry
    @time_entries = time_entries
  end

  def call
    start_time = "#{TimeEntry::DATE} #{@time_entry[:start_time]}".to_time(:utc)
    end_time = "#{TimeEntry::DATE} #{@time_entry[:end_time]}".to_time(:utc)
    splitted_time_entries(start_time, end_time, @time_entries)
  end

  private

  # Verifies if a time entry is overlapped or contained by any time entry from the other time
  #  entries collection. If they are overlapped it removes the overlapped parts and generates the
  # new time entries of the not overlapped parts.
  #
  # @param start_time [Time] start time of the time entry
  # @param end_time [Time] end time of the time entry
  #
  # @return [Array[Array[Time,Time]]] Every array is a time entry. The first time is the start_time
  #  of the time entry and the second time in the array is the end_time of the time entry.
  #
  def splitted_time_entries(start_time, end_time, time_entries_to_base_the_split)
    result = []
    time_entry_in_progress = [start_time, end_time]
    time_entries_to_base_the_split.each do |other_time_entry|
      other_start_time = "#{TimeEntry::DATE} #{other_time_entry[:start_time]}".to_time(:utc)
      other_end_time = "#{TimeEntry::DATE} #{other_time_entry[:end_time]}".to_time(:utc)
      te_start_time = time_entry_in_progress.first
      te_end_time = time_entry_in_progress.last
      if other_start_time <= te_start_time && other_end_time >= te_end_time
        time_entry_in_progress = nil
        break
      elsif other_start_time <= te_start_time && other_end_time < te_end_time &&
          other_end_time > te_start_time
        time_entry_in_progress = [other_end_time, te_end_time]
      elsif other_start_time > te_start_time && other_end_time >= te_end_time &&
          other_start_time < te_end_time
        result.push([te_start_time, other_start_time])
        time_entry_in_progress = nil
        break
      elsif other_start_time > te_start_time && other_end_time < te_end_time
        result.push([te_start_time, other_start_time])
        time_entry_in_progress = [other_end_time, te_end_time]
      end
    end
    time_entry_in_progress.present? ? result.push(time_entry_in_progress) : result
  end
end
