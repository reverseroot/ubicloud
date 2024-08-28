# frozen_string_literal: true

class MonitorableResource
  attr_reader :deleted, :run_event_loop

  PULSE_TIMEOUT = 120

  def initialize(resource)
    @resource = resource
    @session = nil
    @mutex = Mutex.new
    @pulse = {}
    @health = {}
    @pulse_check_started_at = Time.now
    @health_check_started_at = Time.now
    @pulse_thread = nil
    @health_thread = nil
    @run_event_loop = false
    @deleted = false
  end

  def open_resource_session
    return if @session && @pulse[:reading] == "up"

    @session = @resource.reload.init_health_monitor_session
  rescue => ex
    if ex.is_a?(Sequel::NoExistingObject)
      Clog.emit("Resource is deleted.") { {resource_deleted: {ubid: @resource.ubid}} }
      @session = nil
      @deleted = true
    end
  end

  def process_event_loop
    return if @session.nil? || !@resource.needs_event_loop_for_pulse_check?

    @pulse_thread = Thread.new do
      sleep 0.01 until @run_event_loop
      @session[:ssh_session].loop(0.01) { @run_event_loop }
    rescue => ex
      Clog.emit("SSH event loop has failed.") { {event_loop_failure: {ubid: @resource.ubid, exception: Util.exception_to_hash(ex)}} }
      close_resource_session
    end
  end

  def check_pulse
    @run_event_loop = true if @resource.needs_event_loop_for_pulse_check?

    @pulse_check_started_at = Time.now
    begin
      @pulse = @resource.check_pulse(session: @session, previous_pulse: @pulse)
      Clog.emit("Got new pulse.") { {got_pulse: {ubid: @resource.ubid, pulse: @pulse}} } if @pulse[:reading_rpt] % 5 == 1 || @pulse[:reading] != "up"
    rescue => ex
      Clog.emit("Pulse checking has failed.") { {pulse_check_failure: {ubid: @resource.ubid, exception: Util.exception_to_hash(ex)}} }
    end

    @run_event_loop = false if @resource.needs_event_loop_for_pulse_check?
    @pulse_thread&.join
  end

  def check_health
    @run_event_loop = true if @resource.needs_event_loop_for_pulse_check?

    @health_check_started_at = Time.now
    begin
      if @resource.respond_to?(:check_health)
        @health = @resource.check_health(session: @session, previous_health: @health)
        # Todo: Implement logic for @health != "up"
        Clog.emit("Got new health data.") { {got_health: {ubid: @resource.ubid, health: @health}} } if @health[:reading_rpt] % 5 == 1
      else
        check_pulse
      end
    rescue => ex
      Clog.emit("health checking has failed.") { {disk_health_check_failure: {ubid: @resource.ubid, exception: Util.exception_to_hash(ex)}} }
    end

    @run_event_loop = false if @resource.needs_event_loop_for_pulse_check?
    @health_thread&.join
  end

  def close_resource_session
    return if @session.nil?

    @session[:ssh_session].shutdown!
    begin
      @session[:ssh_session].close
    rescue
    end
    @session = nil
  end

  def force_stop_if_stuck
    if @mutex.locked?
      Clog.emit("Resource is locked.") { {resource_locked: {ubid: @resource.ubid}} }
      if @pulse_check_started_at + PULSE_TIMEOUT < Time.now
        Clog.emit("Pulse check has stuck.") { {pulse_check_stuck: {ubid: @resource.ubid}} }
      end
    end
  end

  def lock_no_wait
    return unless @mutex.try_lock

    begin
      yield
    ensure
      @mutex.unlock
    end
  end
end
