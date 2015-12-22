class ManageTimeEntry
  include API::V1::Exceptions
  attr_reader :params, :presence_day, :time_entry, :new_time_entry

  def initialize(params, presence_day)
    @params = params
    @presence_day = presence_day
    @time_entry = nil
    @new_time_entry = nil
  end

  def call
    ActiveRecord::Base.transaction do
      @time_entry = build_time_entry(presence_day, params)
      update_time_entry_and_build_new if time_entry_valid_and_longer_than_day?

      save!
    end
  end

  def time_entry_valid_and_longer_than_day?
    !time_entry.end_time_after_start_time? && time_entry.times_parsable?
  end

  def build_time_entry(presence_day, params)
    presence_day.time_entries.new(params)
  end

  def update_time_entry_and_build_new
    new_entry_params, new_presence_day = new_time_entry_params
    @new_time_entry = build_time_entry(new_presence_day, new_entry_params)
    update_first_time_entry_end_time
  end

  def new_entry_minutes
    parsed_time = Tod::TimeOfDay.parse(time_entry.end_time)
    Tod::Shift.new(Tod::TimeOfDay.new(00, 00),
      Tod::TimeOfDay.new(parsed_time.hour, parsed_time.minute)).duration / 60
  end

  def update_first_time_entry_end_time
    time_entry.end_time = '00:00'
  end

  def new_time_entry_params
    params = { start_time: '00:00', end_time: Tod::TimeOfDay.new(00,00,00) + new_entry_minutes }
    presence_day = next_presence_day
    [params, presence_day]
  end

  def next_presence_day
    next_presence_day = PresenceDay.where(order: presence_day.order + 1).first
    return next_presence_day unless next_presence_day.blank?
    build_new_presence_day
  end

  def build_new_presence_day
    PresenceDay.new(presence_policy: presence_day.presence_policy, order: presence_day.order + 1)
  end

  def new_time_entry_and_day_valid?
    return true unless new_time_entry
    new_time_entry.valid? && new_time_entry.presence_day.valid?
  end

  def save!
    if time_entry.valid? && new_time_entry_and_day_valid?
      time_entry.save!
      new_time_entry.try(:save!)

      new_time_entry ? [time_entry, new_time_entry] : time_entry
    else
      messages = {}
      messages = messages
        .merge(time_entry.errors.messages)
        .merge(new_time_entry_error_messages)

      fail InvalidResourcesError.new(time_entry, messages)
    end
  end

  def new_time_entry_error_messages
    return {} unless new_time_entry
    new_time_entry.errors.messages.merge(new_time_entry.presence_day.errors.messages)
  end
end
