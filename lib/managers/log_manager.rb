class LogManager

  attr_accessor :parser, :processor

  def initialize(parser, processor)
    self.parser = parser
    self.processor = processor
  end

  def logs_received(log_data)  
    value_hashes = HerokuLogParser.parse(log_data).collect { |e| parser.parse(e[:message]) }
    processor.process(value_hashes)
  end
end