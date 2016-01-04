class ManageTimeEntry
  include API::V1::Exceptions
  attr_reader :params, :presence_day, :time_entry, :related_time_entry

  def initialize(params, presence_day)
    @params = params
    @presence_day = presence_day
    @time_entry = nil
    @related_time_entry = nil
  end

  def call
    ActiveRecord::Base.transaction do
      @time_entry = find_or_initialize_time_entry
      @related_time_entry = time_entry.related_entry
      time_entry.attributes = params
      update_time_entry_and_manage_related if longer_than_day_or_has_related?

      save!
    end
  end

  def parsable_and_longer_than_day?
    time_entry.times_parsable? && !time_entry.end_time_after_start_time?
  end

  def longer_than_day_or_has_related?
    parsable_and_longer_than_day? || related_time_entry.present?
  end

  def find_or_initialize_time_entry
    presence_day.time_entries.where(id: params[:id]).first_or_initialize
  end

  def update_time_entry_and_manage_related
    return related_time_entry.destroy! unless parsable_and_longer_than_day?
    related_entry_params, related_presence_day = related_time_entry_params
    @related_time_entry = related_presence_day.time_entries.new unless related_time_entry.present?
    related_time_entry.attributes = related_entry_params
    update_first_time_entry_end_time
  end

  def new_entry_seconds
    parsed_time = Tod::TimeOfDay.parse(time_entry.end_time)
    Tod::Shift.new(Tod::TimeOfDay.new(00, 00),
      Tod::TimeOfDay.new(parsed_time.hour, parsed_time.minute)).duration
  end

  def update_first_time_entry_end_time
    time_entry.end_time = '00:00'
  end

  def related_time_entry_params
    params = { start_time: '00:00', end_time: Tod::TimeOfDay.new(00,00,00) + new_entry_seconds }
    presence_day = next_presence_day
    [params, presence_day]
  end

  def next_presence_day
    PresenceDay.where(order: presence_day.order + 1).first_or_initialize do |day|
      day.presence_policy = presence_day.presence_policy
    end
  end

  def related_time_entry_and_day_valid?
    return true unless related_time_entry
    related_time_entry.valid? && related_time_entry.presence_day.valid?
  end

  def related_time_entry_error_messages
    return {} unless related_time_entry
    related_time_entry.errors.messages.merge(related_time_entry.presence_day.errors.messages)
  end

  def save!
    if time_entry.valid? && related_time_entry_and_day_valid?
      time_entry.save!
      related_time_entry.try(:save!)

      related_time_entry ? [time_entry, related_time_entry] : time_entry
    else
      messages = {}
      messages = messages
        .merge(time_entry.errors.messages)
        .merge(related_time_entry_error_messages)
      fail InvalidResourcesError.new(time_entry, messages)
    end
  end
end
