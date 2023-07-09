# JSONRPC::Client

Simple JSON-RPC 2.0 client implementation. See the [specification](http://www.jsonrpc.org/specification).

## Installation

Add this line to your application's Gemfile:

    gem 'jsonrpc-client'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install jsonrpc-client

## Usage

```
client = JSONRPC::Client.new('http://example.com')
client.add_numbers(1, 2, 3)
```

### Passing a customized connection

By default, the client uses a plain Faraday connection with Faraday's default adapter to connect to the JSON-RPC endpoint. If you wish to customize this connection, you can pass your own Faraday object into the constructor. In this example, SSL verification is disabled and HTTP Basic Authentication is used:

```ruby
connection = Faraday.new { |connection|
  connection.adapter Faraday.default_adapter
  connection.ssl.verify = false  # This is a baaaad idea!
  connection.basic_auth('username', 'password')
}
client = JSONRPC::Client.new("http://example.com", { connection: connection })
```
[Faraday](https://www.rubydoc.info/gems/faraday/Faraday) API may have change, depending on installed version ; with version >= 2.7.10, you need to call for basic-authentification [set_basic_auth](https://www.rubydoc.info/gems/faraday/Faraday%2FConnection:set_basic_auth) method.
```ruby
connection = Faraday.new { |connection|
  connection.adapter Faraday.default_adapter
  connection.ssl.verify = false  # This is a baaaad idea!
  connection.set_basic_auth('username', 'password')
}
client = JSONRPC::Client.new("http://example.com", { connection: connection })
```

More information about Faraday is available at [that project's GitHub page](https://github.com/lostisland/faraday).


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
