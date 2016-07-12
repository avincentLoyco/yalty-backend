class SplitTimeEntriesByTimeEntriesForDate

  def initialize(time_entries_to_split, time_entries_to_base_the_split, time_entries_to_split_type)
    @time_entries_to_split = time_entries_to_split
    @time_entries_to_base_the_split = time_entries_to_base_the_split
    @time_entries_to_split_type = time_entries_to_split_type
  end

  def call
    not_overlapped_time_entries = []
    @time_entries_to_split.each do |time_entry|
      not_overlapped_time_entries +=
        SplitTimeEntryByTimeEntries.new(time_entry, @time_entries_to_base_the_split).call
    end
    format_time_entries(not_overlapped_time_entries)
  end

  private

  def format_time_entries(time_entries_in_time_format)
    time_entries_in_time_format.map do |time_entry|
      {
        type: @time_entries_to_split_type,
        start_time: time_entry.first.strftime('%H:%M:%S'),
        end_time: time_entry.last.strftime('%H:%M:%S')
      }
    end
  end

end
