require_relative "helper"

# The prefork server serves one connection per worker at a time, so an
# idle keep-alive client must not hold the worker forever (tep#277).
module PreforkIdleApp
  SOURCE = <<~RB
    require 'sinatra'

    get '/' do
      "hi"
    end
  RB

  def idle_client
    s = TCPSocket.new("127.0.0.1", @port)
    s.write("GET / HTTP/1.1\r\nHost: x\r\n\r\n")
    s.readpartial(65536)
    s
  end
end

class TestPreforkIdleKeepAlive < TepTest
  include PreforkIdleApp
  app_source PreforkIdleApp::SOURCE

  def test_idle_keepalive_client_does_not_starve_others
    idle = idle_client
    res = Net::HTTP.start("127.0.0.1", @port, read_timeout: 8) { |h| h.get("/") }
    assert_equal "hi", res.body
  ensure
    idle&.close
  end
end

class TestPreforkIdleShutdown < TepTest
  include PreforkIdleApp
  app_source PreforkIdleApp::SOURCE

  def test_sigint_exits_with_an_idle_keepalive_client
    idle = idle_client
    pid = TepHarness.find_by_port(@port)[:pid]
    Process.kill("INT", pid)
    exited = 20.times.any? do
      sleep 0.1
      Process.waitpid(pid, Process::WNOHANG)
    end
    assert exited, "server still running with an idle client after SIGINT"
  ensure
    idle&.close
  end
end
