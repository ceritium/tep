require_relative "helper"

# An app that uses Thread links Spinel's threaded runtime: accepted
# sockets come back non-blocking and sp_ffi_bin_len is thread-local.
class TestThreads < TepTest
  app_source <<~RB
    require 'sinatra'

    get '/sum' do
      threads = []
      4.times { |i| threads << Thread.new(i) { |n| (n + 1) * 10 } }
      total = 0
      threads.each { |t| total += t.value }
      "sum=" + total.to_s
    end

    post '/echo' do
      request.body.read
    end
  RB

  def test_threads_run_in_a_handler
    res = get("/sum")
    assert_equal "200", res.code
    assert_equal "sum=100", res.body.strip
  end

  def test_requests_parse_and_bodies_read
    res = post("/echo", "a=1&b=two")
    assert_equal "200", res.code
    assert_equal "a=1&b=two", res.body.strip
  end
end
