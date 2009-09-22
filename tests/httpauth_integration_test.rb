require 'rubygems'
require 'test/unit'

$LOAD_PATH << "#{File.dirname(__FILE__)}/../lib/"
require "handsoap"
require 'handsoap/http'

module AbstractHttpAuthTestCase

  def test_connect_to_authserver
    http = Handsoap::Http.drivers[self.driver]
    request = Handsoap::Http::Request.new("http://localhost:8080/")
    response = http.send_http_request(request)
    assert_equal 200, response.status
    assert response.body.match(/basic/)
  end

  def test_basic_auth_with_valid_credentials
    http = Handsoap::Http.drivers[self.driver]
    request = Handsoap::Http::Request.new("http://localhost:8080/basic")
    request.set_auth "user", "password"
    response = http.send_http_request(request)
    assert_equal 200, response.status
  end

  def test_basic_auth_with_invalid_credentials
    http = Handsoap::Http.drivers[self.driver]
    request = Handsoap::Http::Request.new("http://localhost:8080/basic")
    request.set_auth "puser", "assword"
    response = http.send_http_request(request)
    assert_equal 401, response.status
  end

  def test_digest_auth_with_valid_credentials
    http = Handsoap::Http.drivers[self.driver]
    request = Handsoap::Http::Request.new("http://localhost:8080/digest")
    request.set_auth "user", "password"
    response = http.send_http_request(request)
    puts response.inspect
    assert_equal 200, response.status
  end

  def test_digest_auth_with_invalid_credentials
    http = Handsoap::Http.drivers[self.driver]
    request = Handsoap::Http::Request.new("http://localhost:8080/digest")
    request.set_auth "puser", "assword"
    response = http.send_http_request(request)
    assert_equal 401, response.status
  end

end

class TestOfNetHttpAuth < Test::Unit::TestCase
  include AbstractHttpAuthTestCase
  def driver
    :net_http
  end
end

class TestOfCurbAuth < Test::Unit::TestCase
  include AbstractHttpAuthTestCase
  def driver
    :curb
  end
end

class TestOfHttpclientAuth < Test::Unit::TestCase
  include AbstractHttpAuthTestCase
  def driver
    :httpclient
  end
end

