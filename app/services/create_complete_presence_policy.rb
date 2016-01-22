class CreateCompletePresencePolicy
  attr_reader :presence_policie, :params

  def initialize(presence_policie, params)
    @presence_policie = presence_policie
    @params = params
  end

  def call
    ActiveRecord::Base.transaction do
      params.each do |presence_day_params|
        time_entries_params = presence_day_params.delete(:time_entries)

        presence_day = presence_policie.presence_days.new(presence_day_params.permit(:minutes, :order))
        if presence_day.valid?
          presence_day.save!
        else
          fail InvalidResourcesError.new(presence_day, presence_day.errors.messages)
        end

        time_entries_params.each do |time_entry_params|
          time_entry = presence_day.time_entries.new(time_entry_params.permit(:start_time, :end_time))
          if time_entry.valid?
            time_entry.save!
          else
            fail InvalidResourcesError.new(time_entry, time_entry.errors.messages)
          end
        end if time_entries_params.present?
      end
    end
  end
end
