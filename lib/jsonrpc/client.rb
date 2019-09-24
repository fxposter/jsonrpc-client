require 'multi_json'
require 'faraday'
require 'uri'
require 'jsonrpc/request'
require 'jsonrpc/response'
require 'jsonrpc/error'
require 'jsonrpc/version'

module JSONRPC
  def self.logger=(logger)
    @logger = logger
  end

  def self.logger
    @logger
  end

  def self.decode_options=(options)
    @decode_options = options
  end

  def self.decode_options
    @decode_options
  end

  @decode_options = {}

  class Helper
    def initialize(options)
      @options = options
      @options[:content_type] ||= 'application/json'
      @connection = @options.delete(:connection)
    end

    def options(additional_options = nil)
      if additional_options
        additional_options.merge(@options)
      else
        @options
      end
    end

    def connection
      @connection || ::Faraday.new { |connection|
        connection.response :logger, ::JSONRPC.logger
        connection.adapter ::Faraday.default_adapter
      }
    end
  end

  class Base < BasicObject
    JSON_RPC_VERSION = '2.0'

    def self.make_id
      rand(10**12)
    end

    def initialize(url, opts = {})
      @url = ::URI.parse(url).to_s
      @helper = ::JSONRPC::Helper.new(opts)
    end

    def to_s
      inspect
    end

    def inspect
      "#<#{self.class.name}:0x00%08x>" % (__id__ * 2)
    end

    def class
      (class << self; self end).superclass
    end

  private
    def raise(*args)
      ::Kernel.raise(*args)
    end
  end

  class BatchClient < Base
    attr_reader :batch

    def initialize(url, opts = {})
      super
      @batch = []
      @alive = true
      yield self
      send_batch
      @alive = false
    end

    def method_missing(sym, *args, &block)
      if @alive
        request = ::JSONRPC::Request.new(sym.to_s, args)
        push_batch_request(request)
      else
        super
      end
    end

  private
    def send_batch_request(batch)
      post_data = ::MultiJson.encode(batch)
      resp = @helper.connection.post(@url, post_data, @helper.options)
      if resp.nil? || resp.body.nil? || resp.body.empty?
        raise ::JSONRPC::Error::InvalidResponse.new
      end

      resp.body
    end

    def process_batch_response(responses)
      responses.each do |resp|
        saved_response = @batch.map { |r| r[1] }.select { |r| r.id == resp['id'] }.first
        raise ::JSONRPC::Error::InvalidResponse.new if saved_response.nil?
        saved_response.populate!(resp)
      end
    end

    def push_batch_request(request)
      request.id = ::JSONRPC::Base.make_id
      response = ::JSONRPC::Response.new(request.id)
      @batch << [request, response]
      response
    end

    def send_batch
      batch = @batch.map(&:first) # get the requests
      response = send_batch_request(batch)

      begin
        responses = ::MultiJson.decode(response, ::JSONRPC.decode_options)
      rescue
        raise ::JSONRPC::Error::InvalidJSON.new(json)
      end

      process_batch_response(responses)
      @batch = []
    end
  end

  class Client < Base
    def method_missing(method, *args, &block)
      invoke(method, args)
    end

    def invoke(method, args, options = nil)
      resp = send_single_request(method.to_s, args, options)

      begin
        data = ::MultiJson.decode(resp, ::JSONRPC.decode_options)
      rescue
        raise ::JSONRPC::Error::InvalidJSON.new(resp)
      end

      process_single_response(data)
    rescue => e
      e.extend(::JSONRPC::Error)
      raise
    end

    private
    def send_single_request(method, args, options)
      post_data = ::MultiJson.encode({
        'jsonrpc' => ::JSONRPC::Base::JSON_RPC_VERSION,
        'method'  => method,
        'params'  => args,
        'id'      => ::JSONRPC::Base.make_id
      })
      resp = @helper.connection.post(@url, post_data, @helper.options(options))

      if resp.nil? || resp.body.nil? || resp.body.empty?
        raise ::JSONRPC::Error::InvalidResponse.new
      end

      resp.body
    end

    def process_single_response(data)
      raise ::JSONRPC::Error::InvalidResponse.new unless valid_response?(data)

      if data['error']
        code = data['error']['code']
        msg = data['error']['message']
        raise ::JSONRPC::Error::ServerError.new(code, msg)
      end

      data['result']
    end

    def valid_response?(data)
      return false if !data.is_a?(::Hash)
      return false if data['jsonrpc'] != ::JSONRPC::Base::JSON_RPC_VERSION
      return false if !data.has_key?('id')
      return false if data.has_key?('error') && data.has_key?('result')

      if data.has_key?('error')
        if !data['error'].is_a?(::Hash) || !data['error'].has_key?('code') || !data['error'].has_key?('message')
          return false
        end

        if !data['error']['code'].is_a?(::Integer) || !data['error']['message'].is_a?(::String)
          return false
        end
      end

      true
    rescue
      false
    end
  end
end
