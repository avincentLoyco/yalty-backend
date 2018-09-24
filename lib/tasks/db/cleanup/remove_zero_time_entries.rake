namespace :db do
  namespace :cleanup do
    desc "Remove time-entries which start and at the same time"
    task remove_zero_time_entries: [:environment] do
      TimeEntry.where("start_time = end_time").destroy_all
      sql = <<-SQL
        SELECT * FROM registered_working_times, json_array_elements(time_entries) ta
        WHERE ta->>'start_time' = ta->>'end_time'
      SQL
      RegisteredWorkingTime.find_by_sql(sql).each do |working_time|
        correct_time_entries =
          working_time.time_entries.reject { |wt| wt["start_time"] == wt["end_time"] }
        working_time.update! time_entries: correct_time_entries
      end
    end
  end
end
