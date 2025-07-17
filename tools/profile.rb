require "ruby-prof"
require "honeybadger"

if Honeybadger.start({api_key: "badgers", debug: true, backend: "null"})
  RubyProf.start and Honeybadger::Agent.at_exit do
    result = RubyProf.stop
    printer = RubyProf::FlatPrinter.new(result)
    printer.print($stdout, {})
  end

  1000.times do
    Honeybadger.notify(error_class: "RubyProf", error_message: "Profiling Honeybadger -- this should never actually be reported.")
  end
end
