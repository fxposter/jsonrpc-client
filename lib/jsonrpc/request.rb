module JSONRPC
  class Request

    attr_accessor :method, :params, :id
    def initialize(method, params, id = nil)
      @jsonrpc = ::JSONRPC::Base::JSON_RPC_VERSION
      @method = method
      @params = params
      @id = id
    end

    def to_h
      h = {
        'jsonrpc' => @jsonrpc,
        'method'  => @method
      }
      h.merge!('params' => @params) if !!@params && !params.empty?
      h.merge!('id' => id)
    end

    def to_json(*a)
      MultiJson.encode(self.to_h)
    end

  end
end
