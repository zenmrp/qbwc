module QBWC
  class Job
    attr_accessor :data, :requests_provided_when_job_added
    attr_reader :name, :account_id, :worker_class

    def initialize(name, enabled, account_id, worker_class, requests = [], data = nil)
      @name = name
      @enabled = enabled
      @account_id = account_id
      @worker_class = worker_class
      @data = data

      default_key = [nil, account_id]
      requests = [requests].compact unless requests.is_a?(Hash) || requests.is_a?(Array)
      requests = { default_key => requests } unless requests.is_a?(Hash) || requests.empty?
      @requests = requests

      @request_index = { default_key => 0 }
    end

    def worker
      worker_class.constantize.new
    end

    def process_response(qbxml_response, response, session, advance)
      QBWC.logger.info 'Processing response.'
      QBWC.logger.info "Job '#{name}' received response: '#{qbxml_response}'." if QBWC.log_requests_and_responses
      request_list = requests(session)
      completed_request = request_list[request_index(session)] if request_list
      advance_next_request(session) if advance
      worker.handle_response(response, session, self, completed_request, data)
    end

    def advance_next_request(session)
      new_index = request_index(session) + 1
      QBWC.logger.info "Job '#{name}' advancing to request #'#{new_index}'."
      @request_index[session.key] = new_index
    end

    def enable
      self.enabled = true
    end

    def disable
      self.enabled = false
    end

    def pending?(session)
      unless enabled?
        QBWC.logger.info "Job '#{name}' not enabled."
        return false
      end
      sr = worker.should_run?(self, session, @data)
      QBWC.logger.info "Job '#{name}' should_run?: #{sr}."
      sr
    end

    def enabled?
      @enabled
    end

    def requests(session)
      secondary_key = session.key.dup
      secondary_key[0] = nil # username = nil
      result = nil
      [session.key, secondary_key].each do |k|
        result ||= (@requests || {})[k]
      end
      result
    end

    def set_requests(session, requests)
      @requests ||= {}
      @requests[session.key] = requests
    end

    attr_writer :requests

    def request_index(session)
      @request_index[session.key] || 0
    end

    def next_request(session = QBWC::Session.get)
      reqs = requests session

      # Generate and save the requests to run when starting the job.
      if (reqs.nil? || reqs.empty?) && !requests_provided_when_job_added
        greqs = worker.requests(self, session, @data)
        greqs = [greqs] unless greqs.nil? || greqs.is_a?(Array)
        set_requests session, greqs
        reqs = requests session
      end

      QBWC.logger.info("Requests available are '#{reqs}'.") if QBWC.log_requests_and_responses
      ri = request_index session
      QBWC.logger.info("Request index is '#{ri}'.")
      return nil if ri.nil? || reqs.nil? || ri >= reqs.length

      nr = reqs[ri]
      QBWC.logger.info("Next request is '#{nr}'.") if QBWC.log_requests_and_responses
      QBWC::Request.new(nr) if nr
    end
    alias next next_request # Deprecated method name 'next'

    def reset
      @request_index = {}
      @requests = {} unless requests_provided_when_job_added
    end
  end
end
