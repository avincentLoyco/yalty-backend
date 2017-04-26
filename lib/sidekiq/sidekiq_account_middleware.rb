class SidekiqAccountMiddleware
  def call(_worker_class, job, _queue, _redis_pool)
    job['args'].each do |args|
      args['account'] = Account.current&.id
      args['user'] = Account::User.current&.id
    end
    yield
  end
end
