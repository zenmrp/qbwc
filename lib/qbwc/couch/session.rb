class QBWC::Couch::Session < QBWC::Session
  class QbwcSession < CouchRest::Model::Base
    
    use_database :qbwc
    
    property :ticket
    property :user
    property :company
    property :pending_jobs #, [String]
    property :current_job
    property :error
    property :progress, Integer, default: 0
    property :iterator_id
    
    timestamps!
    
    #attr_accessor :current_job, :pending_jobs
    
    #attr_accessor :company, :ticket, :user, :pending_jobs, :current_job #unless Rails::VERSION::MAJOR >= 4
    
    #def pending_jobs
    #  []
    #end
    
  end

	def self.get(ticket)
    #puts "get session by ticket"
    # The Ticket Is The ID - Created In QBWC::Session Init 
    ##puts ticket.inspect
		session = QbwcSession.get(ticket)
    self.new(session) if session
	end

  def initialize(session_or_user = nil, company = nil, ticket = nil)
    #puts "initialize session"
    if session_or_user.is_a? QbwcSession
      @session = session_or_user
      # Restore current job from saved one on QbwcSession
      #puts "inspect sesssion from QBWC::Couch::Session"
      #puts @session.inspect 
      @current_job = QBWC.get_job(@session.current_job) if @session.current_job
      # Restore pending jobs from saved list on QbwcSession
      @pending_jobs = @session.pending_jobs.split(',').map { |job_name| QBWC.get_job(job_name) }.select { |job| ! job.nil? }
      super(@session.user, @session.company, @session.ticket)
    else
      super
      @session = QbwcSession.new
      @session.id      = self.ticket  # added by me to set the session to the ticket_id?  bad idea?
      @session.user    = self.user
      @session.company = self.company
      @session.ticket  = self.ticket
      self.save
      @session
    end
  end

  def save
    #puts "save session"
    @session.pending_jobs = pending_jobs.map(&:name).join(',')
    @session.current_job  = current_job.try(:name)
    @session.save
    super
  end

  def destroy
    #puts "destroy sesson"
    @session.destroy
    super
  end
  
  

  [:error, :progress, :iterator_id].each do |method|
    define_method method do
      @session.send(method)
    end
    define_method "#{method}=" do |value|
      @session.send("#{method}=", value)
    end
  end
  protected :progress=, :iterator_id=, :iterator_id

end
