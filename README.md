# Tcr

TCR is a lightweight VCR for TCP sockets.

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

Run this test once, and TCR will record the tcp interactions to fixtures/tcr_cassettes/google_smtp.json. Run it again, and TCR will replay the interactions from google when the tcp request is made. This test is now fast (no real TCP requests are made anymore), deterministic and accurate.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
