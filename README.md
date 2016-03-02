# TCR (TCP + VCR)

[![Build Status](https://travis-ci.org/robforman/tcr.png?branch=master)](https://travis-ci.org/robforman/tcr)



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
  c.hook_tcp_ports = [2525]
end

class TCRTest < Test::Unit::TestCase
  def test_example_dot_com
    TCR.use_cassette('mandrill_smtp') do
      tcp_socket = TCPSocket.open("smtp.mandrillapp.com", 2525)
      io = Net::InternetMessageIO.new(tcp_socket)
      assert_match /220 smtp.mandrillapp.com ESMTP/, io.readline
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
      "220 smtp.mandrillapp.com ESMTP\r\n"
    ]
  ]
]
```

Run it again, and TCR will replay the interactions from json when the tcp request is made. This test is now fast (no real TCP requests are made anymore), deterministic and accurate.

You can disable TCR hooking TCPSocket ports for a given block via `turned_off`:

```ruby
TCR.turned_off do
  tcp_socket = TCPSocket.open("smtp.mandrillapp.com", 2525)
end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
