require 'new_relic/agent/method_tracer'

ActiveRecord::QueryCache.class_eval do
  include ::NewRelic::Agent::MethodTracer

  add_method_tracer :call
end

ActionDispatch::Cookies.class_eval do
  include ::NewRelic::Agent::MethodTracer

  add_method_tracer :call
end

ActiveRecord::Base.class_eval do
  class << self
    include ::NewRelic::Agent::MethodTracer

    add_method_tracer :establish_connection
    add_method_tracer :remove_connection
    add_method_tracer :connection
    add_method_tracer :retrieve_connection
  end
end

ActiveRecord::ConnectionAdapters::ConnectionHandler.class_eval do
  include ::NewRelic::Agent::MethodTracer

  add_method_tracer :establish_connection
  add_method_tracer :retrieve_connection
  add_method_tracer :remove_connection
  add_method_tracer :retrieve_connection_pool
end


ActiveRecord::ConnectionAdapters::ConnectionPool.class_eval do
  include ::NewRelic::Agent::MethodTracer

  add_method_tracer :connection
  add_method_tracer :checkout
  add_method_tracer :checkout_and_verify
  add_method_tracer :acquire_connection
  add_method_tracer :try_to_checkout_new_connection
  add_method_tracer :checkout_new_connection
  add_method_tracer :new_connection
  add_method_tracer :remove
end

ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
  include ::NewRelic::Agent::MethodTracer

  add_method_tracer :lease
  add_method_tracer :verify!
  add_method_tracer :disconnect!
  add_method_tracer :_run_checkout_callbacks
  add_method_tracer :active?
  add_method_tracer :reconnect!
  add_method_tracer :clear_cache!
  add_method_tracer :reset_transaction
  add_method_tracer :query
end

ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::StatementPool.class_eval do
  include ::NewRelic::Agent::MethodTracer

  add_method_tracer :clear
  add_method_tracer :dealloc
end

PGconn.class_eval do
  include ::NewRelic::Agent::MethodTracer

  add_method_tracer :exec
  add_method_tracer :query
end
