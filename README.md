# TCR (TCP + VCR)

[![Build Status](https://travis-ci.org/robforman/tcr.png?branch=master)](https://travis-ci.org/robforman/tcr)

[ ![Codeship Status for SalesLoft/melody](https://www.codeship.io/projects/9fcbda40-6859-0132-9920-3ad5c353d440/status?branch=master)](https://www.codeship.io/projects/53337)




TCR is a *very* lightweight version of [VCR](https://github.com/vcr/vcr) for TCP sockets.

Currently used for recording 'net/smtp' interactions so only a few of the TCPSocket methods are recorded out.

## Installation

Add this line to your application's Gemfile:

    gem 'tcr'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tcr

## Usage

### HTTP
```ruby
require 'test/unit'
require 'tcr'

TCR.configure do |c|
  c.cassette_library_dir = 'fixtures/tcr_cassettes'
  c.hook_tcp_ports = [80]
end

class TCRTest < Test::Unit::TestCase
  def test_example_dot_com
    TCR.use_cassette('google') do
      data = Net::HTTP.get("google.com", "/")
      assert_match /301 Moved/, data
    end
  end
end
```

Run this test once, and TCR will record the tcp interactions to fixtures/tcr_cassettes/google.json.

```json
[
  [
    [
      "write",
      "GET / HTTP/1.1\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: google.com\r\n\r\n"
    ],
    [
      "read",
      "HTTP/1.1 301 Moved Permanently\r\nLocation: http://www.google.com/\r\nContent-Type: text/html; charset=UTF-8\r\nDate: Sun, 08 Feb 2015 02:42:29 GMT\r\nExpires: Tue, 10 Mar 2015 02:42:29 GMT\r\nCache-Control: public, max-age=2592000\r\nServer: gws\r\nContent-Length: 219\r\nX-XSS-Protection: 1; mode=block\r\nX-Frame-Options: SAMEORIGIN\r\nAlternate-Protocol: 80:quic,p=0.02\r\n\r\n<HTML><HEAD><meta http-equiv=\"content-type\" content=\"text/html;charset=utf-8\">\n<TITLE>301 Moved</TITLE></HEAD><BODY>\n<H1>301 Moved</H1>\nThe document has moved\n<A HREF=\"http://www.google.com/\">here</A>.\r\n</BODY></HTML>\r\n"
    ]
  ]
]
```

Run it again, and TCR will replay the interactions from json when the tcp request is made. This test is now fast (no real TCP requests are made anymore), deterministic and accurate.

You can disable TCR hooking TCPSocket ports for a given block via `turned_off`:

```ruby
TCR.turned_off do
  data = Net::HTTP.get("google.com", "/")
end
```

### SMTP
You can use TCR to record any TCP interaction.  Here we record the start of an SMTP session.  **Note that many residential ISPs block port 25 outbound, so this may not work for you.**

```ruby
require 'test/unit'
require 'tcr'

TCR.configure do |c|
  c.cassette_library_dir = 'fixtures/tcr_cassettes'
  c.hook_tcp_ports = [25]
end

class TCRTest < Test::Unit::TestCase
  def test_example_dot_com
    TCR.use_cassette('google_smtp') do
      tcp_socket = TCPSocket.open("aspmx.l.google.com", 25)
      io = Net::InternetMessageIO.new(tcp_socket)
      assert_match /220 mx.google.com ESMTP/, io.readline
    end
  end
end
```

TCR will record the tcp interactions to fixtures/tcr_cassettes/google_smtp.json.

```json
[
  [
    [
      "read",
      "220 mx.google.com ESMTP x3si2474860qas.18 - gsmtp\r\n"
    ]
  ]
]
```

## Configuration
TCR accepts the following configuration parameters:
* **cassette_library_directory**: the directory, relative to your current directory, to save and read recordings from
* **hook_tcp_ports**: the TCP ports that will be intercepted for recording and playback
* **block_for_reads**: when reading data from a cassette, whether TCR should wait for matching "write" data to be written to the socket before allowing a read
* **recording_format**: the format of the cassettes.  Can be :json, :yaml, or :bson

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
