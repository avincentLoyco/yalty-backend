module BaseRules

  def gate_rules
    return put_rules     if request.put?
    return patch_rules   if request.patch?
    return post_rules    if request.post?
    return get_rules     if request.get?
    return delete_rules  if request.delete?
  end

end
