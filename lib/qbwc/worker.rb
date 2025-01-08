module QBWC
  class Worker
    def requests(_job, _session, _data)
      []
    end

    def should_run?(_job, _session, _data)
      true
    end

    def handle_response(response, session, job, request, data); end
  end
end
