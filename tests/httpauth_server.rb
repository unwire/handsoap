# http://microjet.ath.cx/webrickguide/html/html_webrick.html
require 'rubygems'
require 'webrick'

include WEBrick

def start_webrick(config = {})
  # always listen on port 8080
  config.update(:Port => 8080)
  server = HTTPServer.new(config)
  yield server if block_given?
  ['INT', 'TERM'].each {|signal|
    trap(signal) {server.shutdown}
  }
  server.start
end

start_webrick { |server|
  htdigest = HTTPAuth::Htdigest.new('/tmp/webrick-htdigest')
  htdigest.set_passwd "Restricted", "user", "password"
  authenticator = HTTPAuth::DigestAuth.new(
    :UserDB => htdigest,
    :Realm => "Restricted"
  )

  server.mount_proc('/') {|request, response|
    response.body = "<a href='/basic'>basic</a><br/>\n<a href='/digest'>digest</a>\n"
  }

  server.mount_proc('/basic') {|request, response|
    HTTPAuth.basic_auth(request, response, "Restricted") {|user, pass|
      # this block returns true if
      # authentication token is valid
      user == 'user' && pass == 'password'
    }
    response.body = "You are authenticated to see the super secret data\n"
  }

  server.mount_proc('/digest') {|request, response|
    authenticator.authenticate(request, response)
    response.body = "You are authenticated to see the super secret data\n"
  }
}
