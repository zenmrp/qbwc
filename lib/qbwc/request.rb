class QBWC::Request

  attr_reader   :request, :response_proc

  def initialize(request)
    #Handle Cases for a request passed in as a Hash or String
    #If it's a hash verify that it is properly wrapped with qbxml_msg_rq and xml_attributes for on_error events
    #Allow strings of QBXML to be passed in directly. 
    
    ##puts "request class init"
    ##puts request.inspect 
    
    ##puts
    ##puts "request class"
    ##puts request.class
    ##puts
    
    case
    # Added Array
    when request.is_a?(Array)
      ##puts "request is an array!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      first = request.first
      text = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n<?qbxml version=\"14.0\"?>\n<QBXML>\n  <QBXMLMsgsRq onError=\"stopOnError\">" #"<QBXML><QBXMLMsgsRg>"
      request.each do |item|
        ##puts item.inspect
        qbxml_string = QBWC.parser.to_qbxml(item) 
        text += Nokogiri::XML(qbxml_string).xpath('//QBXMLMsgsRq').children.to_s
      end
      ##puts
      ##puts
      ##puts
      text += "</QBXMLMsgsRq>\n</QBXML>\n"
      ##puts text.inspect
      #r = text.present? ? self.class.wrap_request(text) : self.class.wrap_request({})
      @request = text #QBWC.parser.to_qbxml(r, {:validate => true})
      #r = self.class.wrap_request(first)
      #@request = QBWC.parser.to_qbxml(r, {:validate => true})
    when request.is_a?(Hash)
      request = self.class.wrap_request(request)
      @request = QBWC.parser.to_qbxml(request, {:validate => true})
    when request.is_a?(String)
      @request = request
    else
      raise "Request '#{request}' must be a Hash or a String."
    end
  end

  def to_qbxml
    QBWC.parser.to_qbxml(request)
  end

  def to_hash
    hash = QBWC.parser.from_qbxml(@request.to_s)["qbxml"]["qbxml_msgs_rq"]
    hash.except('xml_attributes')
  end

  # Wrap a Hash request with qbxml_msgs_rq, if it's not already.
  def self.wrap_request(request)
    return request if request.keys.include?(:qbxml_msgs_rq)
    wrapped_request = { :qbxml_msgs_rq => {:xml_attributes => {"onError"=> QBWC::on_error } } }
    wrapped_request[:qbxml_msgs_rq] = wrapped_request[:qbxml_msgs_rq].merge(request)
    return wrapped_request
  end

end
