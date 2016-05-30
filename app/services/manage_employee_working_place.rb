class ManageEmployeeWorkingPlace
  attr_reader :employee, :new_effective_at, :oldest_working_place, :working_places_in_range

  def initialize(employee, new_effective_at)
    @employee = employee
    @new_effective_at = parse_new_effective_at(new_effective_at)
    @oldest_working_place = employee.first_employee_working_place
    @working_places_in_range = []
  end

  def call
    return unless new_effective_at
    find_working_places_in_range
    if working_places_in_range.size > 1
      update_last_working_place_and_remove_other
    else
      update_working_place
    end
  end

  private

  def update_last_working_place_and_remove_other
    working_places_to_destroy_size = working_places_in_range.size - 1
    working_place_to_update = working_places_in_range.last

    working_places_in_range.limit(working_places_to_destroy_size).destroy_all
    update_working_place(working_place_to_update)
  end

  def update_working_place(working_place = oldest_working_place)
    working_place.update(effective_at: new_effective_at)
    working_place
  end

  def find_working_places_in_range
    @working_places_in_range =
      employee
      .employee_working_places
      .where(effective_at: oldest_working_place.effective_at..new_effective_at)
      .order(:effective_at)
  end

  def parse_new_effective_at(new_effective_at)
    @new_effective_at =
      begin
        new_effective_at.to_date
      rescue
        nil
      end
  end
end
