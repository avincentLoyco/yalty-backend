class WorkingPlaceRepresenter
  def initialize(working_place)
    @working_place = working_place
  end

  def basic(_ = {})
    {
      id: working_place.id,
      type: set_type
    }
  end

  private

  attr_reader :working_place

  def set_type
    working_place.class.name.underscore
  end
end
