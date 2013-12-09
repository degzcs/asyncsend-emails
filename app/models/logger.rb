module SpaceMandrill
  class Logger < Logger
    def format_message(severity, timestamp, progname, msg)
      "#{timestamp.to_formatted_s(:db)} #{severity} #{msg}\r\n"
    end
  end
end