# This script adds a honeybadger init dependency to each rake task, so that
# we can initialize honeybadger if it hasn't already been, before the task is executed.
Rake.application.tasks.each do |task|
  task.enhance([:"honeybadger:init"]) if task.name != "honeybadger:init"
end
