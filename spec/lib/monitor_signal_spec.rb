# spec/monitor_signal_spec.rb

require_relative "../model/spec_helper"
require_relative '../../lib/monitor_signal'

RSpec.describe MonitorSignal do
  let(:vm_host) { VmHost.new { _1.id = "46683a25-acb1-4371-afe9-d39f303e44b4" } }

  describe Pulse do
    let(:pulse) { Pulse.new(vm_host) }

    describe '#get_status' do
      context 'when pulse checking is successful' do
        it 'returns the pulse status' do
          allow(vm_host).to receive(:check_pulse).and_return({ reading: "up", reading_rpt: 1 })
          expect(Clog).to receive(:emit).at_least(:once)
          status = pulse.get_status(session: {}, prev: nil)
          expect(status).to eq({ reading: "up", reading_rpt: 1 })
        end

        it 'returns the pulse status, no log' do
          allow(vm_host).to receive(:check_pulse).and_return({ reading: "up", reading_rpt: 2 })
          expect(Clog).not_to receive(:emit)
          status = pulse.get_status(session: {}, prev: nil)
          expect(status).to eq({ reading: "up", reading_rpt: 2 })
        end
      end

      context 'when pulse checking fails' do
        it 'returns nil and logs the exception' do
          allow(vm_host).to receive(:check_pulse).and_raise(StandardError.new("Pulse error"))
          expect(Clog).to receive(:emit).with("Pulse checking has failed.")
          status = pulse.get_status(session: {}, prev: nil)
          expect(status).to eq(nil)
        end
      end
    end
  end

  describe DiskHealth do
    let(:disk_health) { DiskHealth.new(vm_host) }
    describe '#get_status' do
      context 'when disk health checking is successful' do
        it 'returns the disk health status' do
          allow(vm_host).to receive(:check_disk_health).and_return({ reading: "up", reading_rpt: 1 })
          expect(Clog).to receive(:emit).at_least(:once)
          status = disk_health.get_status(session: {}, prev: {})
          expect(status).to eq({ reading: "up", reading_rpt: 1 })
        end

        it 'returns the pulse status, no log' do
          allow(vm_host).to receive(:check_disk_health).and_return({ reading: "up", reading_rpt: 2 })
          expect(Clog).not_to receive(:emit)
          status = disk_health.get_status(session: {}, prev: nil)
          expect(status).to eq({ reading: "up", reading_rpt: 2 })
        end
      end

      context 'when disk health checking fails' do
        it 'returns nil and logs the exception' do
          allow(vm_host).to receive(:check_disk_health).and_raise(StandardError.new("Disk health error"))
          expect(Clog).to receive(:emit).with("Disk health checking has failed.")
          status = disk_health.get_status(session: {}, prev: nil)
          expect(status).to eq(nil)
        end
      end
    end
  end

  describe NetworkHealth do
    let(:network_health) { NetworkHealth.new(vm_host) }
    describe '#get_status' do
      context 'when network health checking is successful' do
        it 'returns the network health status' do
          allow(vm_host).to receive(:check_network_health).and_return({ reading: "up", reading_rpt: 1 })
          expect(Clog).to receive(:emit).at_least(:once)
          status = network_health.get_status(session: {}, prev: {})
          expect(status).to eq({ reading: "up", reading_rpt: 1 })
        end
        it 'returns the pulse status, no log' do
          allow(vm_host).to receive(:check_network_health).and_return({ reading: "up", reading_rpt: 2 })
          expect(Clog).not_to receive(:emit)
          status = network_health.get_status(session: {}, prev: nil)
          expect(status).to eq({ reading: "up", reading_rpt: 2 })
        end
      end

      context 'when network health checking fails' do
        it 'returns nil and logs the exception' do
          allow(vm_host).to receive(:check_network_health).and_raise(StandardError.new("Network health error"))
          expect(Clog).to receive(:emit).with("Netowrk health checking has failed.")
          status = network_health.get_status(session: {}, prev: nil)
          expect(status).to eq(nil)
        end
      end
    end
  end

  describe '#get_status' do
    let(:resource) { double("Resource") }
    let(:monitor_signal) { MonitorSignal.new(resource) }
    it 'raises NotImplementedError when called' do
      expect { monitor_signal.get_status(session: {}, prev: {}) }.to raise_error(NotImplementedError, "This method must be overridden")
    end
  end
end