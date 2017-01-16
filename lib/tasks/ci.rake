task :ci do
  Rake::Task[:'parallel:spec'].invoke
end
