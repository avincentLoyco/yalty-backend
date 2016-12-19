def running_task_server
  primary(fetch(:running_task_role, :worker))
end
