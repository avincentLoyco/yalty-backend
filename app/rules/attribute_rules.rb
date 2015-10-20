module AttributeRules

  def gate_rules(request)
    return put_rules     if request == 'PUT'
    return patch_rules   if request == 'PATCH'
    return post_rules    if request == 'POST'
  end
end
