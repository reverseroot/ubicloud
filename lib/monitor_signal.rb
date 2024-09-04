# frozen_string_literal: true

# Base class for monitor signals
class MonitorSignal
    attr_accessor :resource, :status
  
    def initialize(resource)
      @resource = resource
    end
  
    def get_status(session:, prev:)
      raise NotImplementedError, "This method must be overridden"
    end
  end
  
  class Pulse < MonitorSignal
    def get_status(session:, prev:)
      begin
        @pulse = @resource.check_pulse(session: session, previous_pulse: prev)
        Clog.emit("Got new pulse.") { {got_pulse: {ubid: @resource.ubid, pulse: @pulse}} } if @pulse[:reading_rpt] % 5 == 1 || @pulse[:reading] != "up"
      rescue => ex
        Clog.emit("Pulse checking has failed.") { {pulse_check_failure: {ubid: @resource.ubid, exception: Util.exception_to_hash(ex)}} }
      end
      @pulse
    end
  end
  
  class DiskHealth < MonitorSignal
    def get_status(session:, prev:)
      begin
        @disk_health = @resource.check_disk_health(session: session, previous_disk_health: prev)
        Clog.emit("Got new disk health.") { {got_disk_health: {ubid: @resource.ubid, pulse: @disk_health}} } if @disk_health[:reading_rpt] % 5 == 1 || @disk_health[:reading] != "up"
      rescue => ex
        Clog.emit("Disk health checking has failed.") { {pulse_check_failure: {ubid: @resource.ubid, exception: Util.exception_to_hash(ex)}} }
      end
      @disk_health
    end
  end
