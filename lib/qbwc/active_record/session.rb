module QBWC
  module ActiveRecord
    class Session < QBWC::Session
      class QbwcSession < ApplicationRecord
        attr_accessible :account_id, :ticket, :user unless Rails::VERSION::MAJOR >= 4
      end

      def self.get(ticket)
        session = QbwcSession.find_by_ticket(ticket)
        new(session) if session
      end

      def initialize(session_or_user = nil, account_id = nil, ticket = nil)
        if session_or_user.is_a? QbwcSession
          @session = session_or_user
          # Restore current job from saved one on QbwcSession
          @current_job = QBWC.get_job(@session.current_job, @session.account_id) if @session.current_job
          # Restore pending jobs from saved list on QbwcSession
          @pending_jobs = @session.pending_jobs.split(',').map do |job_name|
            QBWC.get_job(job_name, @session.account_id)
          end.reject(&:nil?)
          super(@session.user, @session.account_id, @session.ticket)
        else
          super
          @session = QbwcSession.new
          @session.user = user
          @session.account_id = self.account_id
          @session.ticket = self.ticket
          save
          @session
        end
      end

      def save
        @session.pending_jobs = pending_jobs.map(&:name).join(',')
        @session.current_job = current_job.try(:name)
        @session.save
        super
      end

      def destroy
        @session.destroy
        super
      end

      %i[error progress iterator_id].each do |method|
        define_method method do
          @session.send(method)
        end
        define_method "#{method}=" do |value|
          @session.send("#{method}=", value)
        end
      end

      :progress=
    end
  end
end
