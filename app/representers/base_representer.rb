class BaseRepresenter
  def basic(_ = {})
    {
      id: resource.id,
      type: set_type
    }
  end

  private

  def set_type
    resource.class.name.underscore
  end
end
