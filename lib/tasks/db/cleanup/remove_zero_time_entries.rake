namespace :db do
  namespace :cleanup do
    desc "Remove time-entries which start and at the same time"
    task remove_zero_time_entries: [:environment] do
      TimeEntry.where("start_time = end_time").destroy_all
    end
  end
end
