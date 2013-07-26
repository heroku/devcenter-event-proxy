class LogManager

  attr_accessor :parser, :processor

  def initialize(parser, processor)
    self.parser = parser
    self.processor = processor
  end

  def logs_received(log_data)  
    value_hashes = HerokuLogParser.parse(log_data).collect do |e|
    	puts "at=debug event=collect log=\"#{log_data.inspect}\" data=\"#{e.inspect}\""
    	parser.parse(e[:message])
    end
    puts "at=debug log-data=\"#{log_data.inspect}\" parsed-data=\"#{value_hashes.inspect}\""
    processor.process(value_hashes)
  end
end