class QBWC::Couch::Job < QBWC::Job
  class QbwcJob < CouchRest::Model::Base
    
    use_database :qbwc
    
    property :name
    property :company
    property :enabled
    property :worker_class
    property :requests_provided_when_job_added
    
    property :requests, [Hash]
    property :request_index, Hash
    property :data, Hash
    
    timestamps!
    
    
    #validates :name, :uniqueness => { :case_sensitive => true }, presence: true
    
    
    design do
      view :all
      view :by_name, 
        map: "function(doc) { 
          if (doc.type == 'QBWC::Couch::Job::QbwcJob') {
            emit(doc.name, 1);
          }      
        }"
    end
    
    #serialize :requests, Hash
    #serialize :request_index, Hash
    #serialize :data

    def to_qbwc_job
      #puts "to_qbwc_job"
      
      QBWC::Couch::Job.new(name, enabled, company, worker_class, requests, data)
    end

  end

  # Creates and persists a job.
  def self.add_job(name, enabled, company, worker_class, requests, data)
    worker_class        = worker_class.to_s
    ar_job              = find_ar_job_with_name(name) || QbwcJob.new
    ar_job.name         = name
    ar_job.company      = company
    ar_job.enabled      = enabled
    ar_job.worker_class = worker_class
    ar_job.data         = data
    ar_job.save!

    jb = self.new(name, enabled, company, worker_class, requests, data)
    
    unless requests.nil? || requests.empty?
     
      request_hash = { [nil, company] => [requests].flatten }
      #request_hash = { [nil, company] => [requests] }
      
      #puts "request hash"
      #puts request_hash.inspect

      jb.requests = request_hash
      ar_job.requests = request_hash
      ar_job.save
    end
    #puts "called"
    #puts jb.class
    #puts jb.name
    #puts requests.inspect 
    
    jb.requests_provided_when_job_added = (! requests.nil? && ! requests.empty?)
    #puts "called 2"
    jb.data = data
    jb
  end

  def self.find_job_with_name(name)
    #puts "called self.find_job_with_name"
    j = find_ar_job_with_name(name)
    j = j.to_qbwc_job unless j.nil?
    return j
  end

  def self.find_ar_job_with_name(name)
    #puts "find ar job with name"
    QbwcJob.by_name({ key: name }).first
  end

  def find_ar_job
    #puts "find ar job"
    
    ##puts self.class
    ##puts self.name
   
    ##puts self.class.find_ar_job_with_name({ key: name }).inspect 
    ##puts "find ar job"
    self.class.find_ar_job_with_name(name)
  end

  def self.delete_job_with_name(name)
    #puts "delete job with name"
    
    j = find_ar_job_with_name(name)
    j.destroy unless j.nil?
  end

  def enabled=(value)
    #puts "enabled setter"
    
    #find_ar_job.update_all(:enabled => value)
    
    the_job = find_ar_job
    the_job.enabled = value
    the_job.save
  end

  def enabled?
    #puts "enabled?"
    
    find_ar_job.enabled
  end

  def requests(session = QBWC::Session.get)
    #puts "called job requests"
    #puts find_ar_job.requests.first.inspect
    @requests = find_ar_job.requests #.first
    super
  end

  def set_requests(session, requests)
    #puts "called set requests"
    
    #puts requests.inspect 
    super
    the_job = find_ar_job
    the_job.requests = @requests
    the_job.save
  end

  def requests_provided_when_job_added
    #puts "requests_provided_when_job_added getter"
    #find_ar_job.requests_provided_when_job_added.first rescue nil
    find_ar_job.requests_provided_when_job_added rescue nil
  end

  def requests_provided_when_job_added=(value)
    #puts "requests_provided_when_job_added setter"
    ##puts value.inspect
    ##puts find_ar_job.inspect
    the_job = find_ar_job
    the_job.requests_provided_when_job_added = value
    the_job.save
    super
  end

  def data
    #puts "data getter"
    
    find_ar_job.data
  end

  def data=(r)
    #puts "data setter"
    find_ar_job.data = r
    super
  end

  def request_index(session)
    #puts "request index"
    
    (find_ar_job.request_index || {})[session.key] || 0
  end

  def set_request_index(session, index)
    #puts "set request index"
    
    #find_ar_job.each do |jb|
    #  jb.request_index[session.key] = index
    #  jb.save
    #end
    the_job = find_ar_job
    the_job.request_index[session.key] = index
    the_job.save
  end

  def advance_next_request(session)
    #puts "advance next request"
    
    nr = request_index(session)
    set_request_index session, nr + 1
  end

  def reset
    #puts "reset"
    super
    the_job = find_ar_job
    the_job.request_index = {}
    the_job.requests = [] unless self.requests_provided_when_job_added
    
    #the_job.requests = {} unless self.requests_provided_when_job_added
    the_job.save
  end

  def self.list_jobs
    #puts "list jobs"
    QbwcJob.all.map {|ar_job| ar_job.to_qbwc_job }
  end

  def self.clear_jobs
    #puts "clear jobs"
    QbwcJob.delete_all
  end

  def self.sort_in_time_order(ary)
    #puts "sort in time order"
    
    ary.sort {|a,b| a.find_ar_job.created_at <=> b.find_ar_job.created_at}
  end

end
