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

Run this test once, and TCR will record the tcp interactions to fixtures/tcr_cassettes/google_smtp.json.

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

Run it again, and TCR will replay the interactions from json when the tcp request is made. This test is now fast (no real TCP requests are made anymore), deterministic and accurate.

You can disable TCR hooking TCPSocket ports for a given block via `turned_off`:

```ruby
TCR.turned_off do
  tcp_socket = TCPSocket.open("aspmx.l.google.com", 25)
end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
