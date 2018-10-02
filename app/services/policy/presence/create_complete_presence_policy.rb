module Policy
  module Presence
    # this service is creating present days with time entries for existing presence policy
    class CreateCompletePresencePolicy
      include API::V1::Exceptions
      pattr_initialize :presence_policy, :params

      def call
        ActiveRecord::Base.transaction do
          params.each do |presence_day_params|
            time_entries_params = presence_day_params.delete(:time_entries)

            presence_day =
              presence_policy.presence_days.new(presence_day_params.permit(:minutes, :order))
            verify_and_save(presence_day)

            next unless time_entries_params.present?
            time_entries_params.each do |time_entry_params|
              time_entry =
                presence_day.time_entries.new(time_entry_params.permit(:start_time, :end_time))
              verify_and_save(time_entry)
            end
          end
        end
      end

      private

      def verify_and_save(resource)
        raise InvalidResourcesError.new(resource, resource.errors.messages) unless resource.valid?
        resource.save!
      end
    end
  end
end
