require 'honeybadger'

CRASHES = {
  "system_exit" => ->{ exit -1 },
  "sigterm" => ->{ raise SignalException, "TERM" },
  "hup" => ->{ raise SignalException, "HUP" },
}

crash_type = ARGV.first || (raise "Invalid argument")

(CRASHES[crash_type] || ->{ raise "Invalid crash type" }).()
