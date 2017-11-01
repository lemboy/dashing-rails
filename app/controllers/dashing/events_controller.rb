module Dashing
  class EventsController < ApplicationController
    include ActionController::Live

    skip_before_action :verify_authenticity_token, only: [:close_stream]
    before_action :define_variables, :prepare_headers, :set_stream_id,
                  only: :index

    def index
      response.stream.write latest_events

      @redis = Dashing.redis
      @redis.psubscribe(@channels) do |on|
        on.pmessage do |_pattern, event, data|
          if event =~ /#{@namespace}/
            response.stream.write("data: #{data}\n\n")
          elsif event == @heartbeat_channel
            response.stream.write("data: {}\n\n")
          elsif event == @close_stream_channel &&
                response.headers['Stream-Id'].to_f == data.to_f
            response.stream.close
          end
        end
      end
    rescue IOError
      logger.info "[Dashing][#{Time.now.utc}] Stream closed"
    ensure
      @redis.quit
      response.stream.close
    end

    def close_stream
      REDIS.publish(
        Dashing.config.close_stream_channel, params[:stream_id].to_f
      )
      render nothing: true
    end

    private

    def define_variables
      @namespace = Dashing.config.redis_namespace
      @heartbeat_channel = Dashing.config.heartbeat_channel
      @close_stream_channel = Dashing.config.close_stream_channel
      @channels = ["#{@namespace}.*"]
      @channels << @heartbeat_channel if Dashing.config.use_heartbeat
      @channels << @close_stream_channel if Dashing.config.close_stream_with_js
    end

    def prepare_headers
      response.headers['Content-Type'] = 'text/event-stream'
      response.headers['X-Accel-Buffering'] = 'no'
    end

    def set_stream_id
      return unless Dashing.config.close_stream_with_js
      @stream_id = Time.current.to_f
      response.headers['Stream-Id'] = @stream_id.to_s
      response.stream.write("data: {\"stream_id\":#{@stream_id}}\n\n")
    end

    def latest_events
      events = Dashing.redis.hvals("#{@namespace}.latest")
      events.map { |v| "data: #{v}\n\n" }.join
    end
  end
end
