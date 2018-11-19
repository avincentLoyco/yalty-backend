module PresencePolicies
  # Create present days with time entries for existing presence policy
  class CreatePresenceDays
    def call(presence_policy:, params:)
      @presence_policy = presence_policy

      ActiveRecord::Base.transaction do
        params.each do |presence_day_params|
          time_entries_params = presence_day_params.delete(:time_entries)

          create_presence_day(presence_day_params).tap do |presence_day|
            create_time_entries(presence_day, time_entries_params)
          end
        end
      end
    end

    private

    attr_reader :presence_policy

    def create_presence_day(params)
      presence_policy.presence_days
        .new(presence_day_permitted_params(params))
        .tap(&:save!)
    end

    def create_time_entries(presence_day, time_entries_params)
      return unless time_entries_params.present?

      time_entries_params.each do |params|
        create_time_entry(presence_day, params)
      end
    end

    def create_time_entry(presence_day, params)
      presence_day.time_entries
        .new(time_entry_permitted_params(params))
        .tap(&:save!)
    end

    def presence_day_permitted_params(params)
      params.permit(:order)
    end

    def time_entry_permitted_params(params)
      params.permit(:start_time, :end_time)
    end
  end
end
