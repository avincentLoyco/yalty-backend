class ManageTimeEntry
  include API::V1::Exceptions
  attr_reader :params, :presence_day, :time_entry, :related_time_entry

  def initialize(params, presence_day)
    @params = params
    @presence_day = presence_day
    @time_entry = find_or_initialize_time_entry
    @related_time_entry = time_entry.related_entry
  end

  def call
    ActiveRecord::Base.transaction do
      time_entry.attributes = params
      update_time_entry_and_manage_related if longer_than_day_or_has_related?
      UpdatePresenceDayMinutes.new([presence_day, related_time_entry.try(:presence_day)]).call

      save!
    end
  end

  def find_or_initialize_time_entry
    presence_day.time_entries.where(id: params[:id]).first_or_initialize
  end

  def update_time_entry_and_manage_related
    return related_time_entry.destroy! if time_entry.end_time_after_start_time?
    build_or_update_related_time_entry
    time_entry.end_time = '00:00:00'
  end

  def build_or_update_related_time_entry
    related_entry_params, related_presence_day = related_time_entry_params
    @related_time_entry = related_presence_day.time_entries.new unless related_time_entry.present?
    related_time_entry.attributes = related_entry_params
  end

  def related_entry_seconds
    parsed_time = Tod::TimeOfDay.parse(time_entry.end_time)
    Tod::Shift.new(Tod::TimeOfDay.new(00, 00),
      Tod::TimeOfDay.new(parsed_time.hour, parsed_time.minute)).duration
  end

  def related_time_entry_params
    presence_day = related_presence_day
    params = {
      start_time: '00:00',
      end_time: Tod::TimeOfDay.new(00, 00, 00) + related_entry_seconds
    }
    [params, presence_day]
  end

  def related_presence_day
    PresenceDay.where(order: presence_day.order + 1).first_or_initialize do |day|
      day.presence_policy = presence_day.presence_policy
    end
  end

  def longer_than_day_or_has_related?
    time_entry.times_parsable? &&
      (related_time_entry.present? || !time_entry.end_time_after_start_time?)
  end

  def related_time_entry_and_day_valid?
    related_time_entry.blank? ||
      (related_time_entry.valid? && related_time_entry.presence_day.valid?)
  end

  def related_time_entry_error_messages
    return {} unless related_time_entry
    related_time_entry.errors.messages.merge(related_time_entry.presence_day.errors.messages)
  end

  def save!
    if time_entry.valid? && time_entry.presence_day.valid? && related_time_entry_and_day_valid?
      time_entry.save!
      related_time_entry.try(:save!)

      related_time_entry ? [time_entry, related_time_entry] : time_entry
    else
      messages = {}
      messages = messages
        .merge(time_entry.errors.messages)
        .merge(time_entry.presence_day.errors.messages)
        .merge(related_time_entry_error_messages)
      fail InvalidResourcesError.new(time_entry, messages)
    end
  end
end
