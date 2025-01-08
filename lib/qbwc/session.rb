module QBWC
  class Session
    attr_reader :user, :company, :ticket, :progress
    attr_accessor :error, :status_code, :status_severity

    @@session = nil

    def self.get(_ticket = nil)
      @@session
    end

    def initialize(user = nil, company = nil, ticket = nil)
      @user = user
      @company = company
      @current_job = nil
      @error = nil
      @progress = 0
      @iterator_id = nil
      @initial_job_count = pending_jobs.length

      @ticket = ticket || Digest::SHA1.hexdigest("#{Rails.application.config.try(:secret_key_base) || Rails.application.config.try(:secret_token)}#{SecureRandom.uuid}")

      @@session = self
      reset(ticket.nil?)
    end

    def key
      [user, company]
    end

    def response_is_error?
      error && status_severity == 'Error'
    end

    def error_and_stop_requested?
      response_is_error? && QBWC.on_error == 'stopOnError'
    end

    def finished?
      progress == 100
    end

    def next_request
      if current_job.nil? || error_and_stop_requested?
        self.progress = 100
        complete_with_success unless response_is_error?
        return nil
      end
      until (request = current_job.next_request(self))
        pending_jobs.shift
        reset(true) or break
      end
      jobs_completed = @initial_job_count - pending_jobs.length
      self.progress = ((jobs_completed.to_f / @initial_job_count) * 100).to_i
      complete_with_success if finished?
      request
    end
    alias next next_request # Deprecated method name 'next'

    def current_request
      request = next_request
      if request && iterator_id.present?
        request = request.to_hash
        requestID = request.values.first['xml_attributes']['requestID']
        request.delete('xml_attributes')
        request.values.first['xml_attributes'] =
          { 'iterator' => 'Continue', 'iteratorID' => iterator_id, 'requestID' => requestID }
        request = QBWC::Request.new(request)
      end
      request
    end

    def request_to_send
      current_job_name = current_job.name
      request = current_request.try(:request) || ''
      QBWC.logger.info("Sending request from job #{current_job_name}")
      QBWC.logger.info(request) if QBWC.log_requests_and_responses

      request
    end

    def response=(qbxml_response)
      QBWC.logger.info 'Parsing response.'
      unless qbxml_response.nil?
        response = QBWC.parser.from_qbxml(qbxml_response)['qbxml']['qbxml_msgs_rs'].except('xml_attributes')
        response = response[response.keys.first]
        parse_response_header(response)
      end
      current_job.process_response(qbxml_response, response, self, iterator_id.blank?) unless current_job.nil?
      next_request # search next request
    rescue StandardError => e
      self.error = e.message
      QBWC.logger.warn "An error occured in QBWC::Session: #{e.message}"
      QBWC.logger.warn e.backtrace.join("\n")
    end

    def save; end

    def began_at
      @session.created_at
    end

    def destroy
      freeze
      @@session = nil
    end

    protected

    attr_accessor :current_job, :iterator_id
    attr_writer :progress

    private

    def reset(reset_job = false)
      self.current_job = pending_jobs.first
      current_job.reset if reset_job && current_job
      current_job
    end

    def pending_jobs
      @pending_jobs ||= QBWC.pending_jobs(@company, self)
    end

    def complete_with_success
      QBWC.session_complete_success.call(self) if QBWC.session_complete_success
    end

    def parse_response_header(response)
      QBWC.logger.info 'Parsing headers.'

      self.iterator_id = nil
      self.error = nil
      self.status_code = nil
      self.status_severity = nil

      if response.is_a? Array
        response = response.find do |r|
          r.is_a?(Hash) && r['xml_attributes'] && r['xml_attributes']['statusCode'].to_i > 1
        end || response.first
      end
      return unless response.is_a?(Hash) && response['xml_attributes']

      @status_code, @status_severity, status_message, iterator_remaining_count, iterator_id = \
        response['xml_attributes'].values_at('statusCode', 'statusSeverity', 'statusMessage',
                                             'iteratorRemainingCount', 'iteratorID')
      QBWC.logger.info "Parsed headers. statusSeverity: '#{status_severity}'. statusCode: '#{@status_code}'"

      if @status_severity == 'Error' || @status_severity == 'Warn'
        self.error = "QBWC #{@status_severity.upcase}: #{@status_code} - #{status_message}"
        @status_severity == 'Error' ? QBWC.logger.error(error) : QBWC.logger.warn(error)
      end

      self.iterator_id = iterator_id if iterator_remaining_count.to_i > 0 && @status_severity != 'Error'
    end
  end
end
