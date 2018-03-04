# This script adds a honeybadger init dependency to each rake task, so that
# we can initialize honeybadger if it hasn't already been, before the task is executed.
Rake.application.tasks.each do |task|
  unless %w[honeybadger:init environment].include?(task.name)
    task.enhance([:"honeybadger:init"])
  end
end
