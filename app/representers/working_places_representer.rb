class WorkingPlacesRepresenter < BaseRepresenter
  def initialize(working_places)
    @working_places = working_places
  end

  def basic(_ = {})
    {
      working_places: working_places.map do |working_place|
        WorkingPlaceRepresenter.new(working_place).basic
      end
    }
  end

  private

  attr_reader :working_places
end
