require_relative "helper"

module RequestIpApp
  def test_request_ip_is_the_peer_address
    res = get("/ip")
    assert_equal "200", res.code
    assert_equal "127.0.0.1", res.body.strip
  end
end

class TestRequestIp < TepTest
  include RequestIpApp
  app_source <<~RB
    require 'sinatra'

    get '/ip' do
      request.ip
    end
  RB
end

class TestRequestIpScheduled < TepTest
  include RequestIpApp
  app_source <<~RB
    require 'sinatra'
    set :scheduler, :scheduled

    get '/ip' do
      request.ip
    end
  RB
end
