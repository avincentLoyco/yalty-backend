class AssignMember
  attr_reader :resource, :member_id, :member_name

  def initialize(resource, member_id, member_name)
    @resource = resource
    @member_id = member_id
    @member_name = member_name
  end

  def call
    resource.update(member_name => member)
  end

  private

  def member
    Account.current.send(member_name.pluralize).find(member_id)
  end
end
