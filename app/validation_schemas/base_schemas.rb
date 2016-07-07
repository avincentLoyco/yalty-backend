module BaseSchemas
  def dry_validation_schema
    return put_schema   if request.put?
    return patch_schema if request.patch?
    return post_schema  if request.post?
    return get_schema   if request.get?
  end
end
