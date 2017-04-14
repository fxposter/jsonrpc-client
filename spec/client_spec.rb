require 'spec_helper'

module JSONRPC
  describe Client do
    BOILERPLATE = {'jsonrpc' => '2.0', 'id' => 1}

    let(:connection) { double('connection') }

    before(:each) do
      @resp_mock = double('http_response')
      Base.stub(:make_id).and_return(1)
    end

    after(:each) do
    end

    describe "hidden methods" do
      it "should reveal inspect" do
        Client.new(SPEC_URL).inspect.should match /JSONRPC::Client/
      end

      it "should reveal to_s" do
        Client.new(SPEC_URL).to_s.should match /JSONRPC::Client/
      end
    end

    describe "#invoke" do
      let(:expected) { MultiJson.encode({
         'jsonrpc' => '2.0',
         'method'  => 'foo',
         'params'  => [1,2,3],
         'id'      => 1
        })
      }

      before(:each) do
        response = MultiJson.encode(BOILERPLATE.merge({'result' => 42}))
        @resp_mock.should_receive(:body).at_least(:once).and_return(response)
        @client = Client.new(SPEC_URL, :connection => connection)
      end

      context "when using an array of args" do
        it "sends a request with the correct method and args" do
          connection.should_receive(:post).with(SPEC_URL, expected, {:content_type => 'application/json'}).and_return(@resp_mock)
          @client.invoke('foo', [1, 2, 3]).should == 42
        end
      end

      context "with headers" do
        it "adds additional headers" do
          connection.should_receive(:post).with(SPEC_URL, expected, {:content_type => 'application/json', "X-FOO" => "BAR"}).and_return(@resp_mock)
          @client.invoke('foo', [1, 2, 3], "X-FOO" => "BAR").should == 42
        end
      end
    end

    describe "sending a single request" do
      context "when using positional parameters" do
        before(:each) do
          @expected = MultiJson.encode({
                       'jsonrpc' => '2.0',
                       'method'  => 'foo',
                       'params'  => [1,2,3],
                       'id'      => 1
          })
        end
        it "sends a valid JSON-RPC request and returns the result" do
          response = MultiJson.encode(BOILERPLATE.merge({'result' => 42}))
          connection.should_receive(:post).with(SPEC_URL, @expected, {:content_type => 'application/json'}).and_return(@resp_mock)
          @resp_mock.should_receive(:body).at_least(:once).and_return(response)
          client = Client.new(SPEC_URL, :connection => connection)
          client.foo(1,2,3).should == 42
        end

        it "sends a valid JSON-RPC request with custom options" do
          response = MultiJson.encode(BOILERPLATE.merge({'result' => 42}))
          connection.should_receive(:post).with(SPEC_URL, @expected, {:content_type => 'application/json', :timeout => 10000}).and_return(@resp_mock)
          @resp_mock.should_receive(:body).at_least(:once).and_return(response)
          client = Client.new(SPEC_URL, :timeout => 10000, :connection => connection)
          client.foo(1,2,3).should == 42
        end

        it "sends a valid JSON-RPC request with custom content_type" do
          response = MultiJson.encode(BOILERPLATE.merge({'result' => 42}))
          connection.should_receive(:post).with(SPEC_URL, @expected, {:content_type => 'application/json-rpc', :timeout => 10000}).and_return(@resp_mock)
          @resp_mock.should_receive(:body).at_least(:once).and_return(response)
          client = Client.new(SPEC_URL, :timeout => 10000, :content_type => 'application/json-rpc', :connection => connection)
          client.foo(1,2,3).should == 42
        end
      end
      context "when using named parameters" do
        before(:each) do
          @expected = MultiJson.encode({
                           'jsonrpc' => '2.0',
                           'method'  => 'foo',
                           'params'  => {:p1 => 1, :p2 => 2, :p3 => 3},
                           'id'      => 1
          })
        end
        it "sends a valid JSON-RPC request and returns the result" do
          response = MultiJson.encode(BOILERPLATE.merge({'result' => 42}))
          connection.should_receive(:post).with(SPEC_URL, @expected, {:content_type => 'application/json'}).and_return(@resp_mock)
          @resp_mock.should_receive(:body).at_least(:once).and_return(response)
          client = Client.new(SPEC_URL, :connection => connection, :named_params => true)
          result = client.foo({:p1 => 1, :p2 => 2, :p3 => 3})
          result.should == 42
        end
      end
    end

    describe "sending a batch request" do
      context "when using positional parameters" do
        it "sends a valid JSON-RPC batch request and puts the results in the response objects" do
          batch = MultiJson.encode([
            {"jsonrpc" => "2.0", "method" => "sum", "params" => [1,2,4], "id" => "1"},
            {"jsonrpc" => "2.0", "method" => "subtract", "params" => [42,23], "id" => "2"},
            {"jsonrpc" => "2.0", "method" => "foo_get", "params" => [{"name" => "myself"}], "id" => "5"},
            {"jsonrpc" => "2.0", "method" => "get_data", "id" => "9"}
          ])

          response = MultiJson.encode([
            {"jsonrpc" => "2.0", "result" => 7, "id" => "1"},
            {"jsonrpc" => "2.0", "result" => 19, "id" => "2"},
            {"jsonrpc" => "2.0", "error" => {"code" => -32601, "message" => "Method not found."}, "id" => "5"},
            {"jsonrpc" => "2.0", "result" => ["hello", 5], "id" => "9"}
          ])

          Base.stub(:make_id).and_return('1', '2', '5', '9')
          connection.should_receive(:post).with(SPEC_URL, batch, {:content_type => 'application/json'}).and_return(@resp_mock)
          @resp_mock.should_receive(:body).at_least(:once).and_return(response)
          client = Client.new(SPEC_URL, :connection => connection)

          sum = subtract = foo = data = nil
          client = BatchClient.new(SPEC_URL, :connection => connection) do |batch|
            sum = batch.sum(1,2,4)
            subtract = batch.subtract(42,23)
            foo = batch.foo_get('name' => 'myself')
            data = batch.get_data
          end

          sum.succeeded?.should be_true
          sum.is_error?.should be_false
          sum.result.should == 7

          subtract.result.should == 19

          foo.is_error?.should be_true
          foo.succeeded?.should be_false
          foo.error['code'].should == -32601

          data.result.should == ['hello', 5]


          expect { client.sum(1, 2) }.to raise_error(NoMethodError)
        end
        context "when using named parameters" do
          it "sends a valid JSON-RPC batch request and puts the results in the response objects" do
            batch = MultiJson.encode([
              {"jsonrpc" => "2.0", "method" => "sum", "params" => [1,2,4], "id" => "1"},
              {"jsonrpc" => "2.0", "method" => "subtract", "params" => [42,23], "id" => "2"},
              {"jsonrpc" => "2.0", "method" => "hello", "params" => ['world'], "id" => "3"},
              {"jsonrpc" => "2.0", "method" => "foo_get", "params" => {"name" => "myself"}, "id" => "5"},
              {"jsonrpc" => "2.0", "method" => "foo", "params" => [[1,2,3]], "id" => "7"},
              {"jsonrpc" => "2.0", "method" => "foo", "params" => {:some => { :nested => :hash }}, "id" => "8"},
              {"jsonrpc" => "2.0", "method" => "get_data", "id" => "9"}
            ])

            response = MultiJson.encode([
              {"jsonrpc" => "2.0", "result" => 7, "id" => "1"},
              {"jsonrpc" => "2.0", "result" => 19, "id" => "2"},
              {"jsonrpc" => "2.0", "result" => 'world', "id" => "3"},
              {"jsonrpc" => "2.0", "error" => {"code" => -32601, "message" => "Method not found."}, "id" => "5"},
              {"jsonrpc" => "2.0", "result" => [2,4,6], "id" => "7"},
              {"jsonrpc" => "2.0", "result" => "I can handle this!", "id" => "8"},
              {"jsonrpc" => "2.0", "result" => ["hello", 5], "id" => "9"}
            ])

            Base.stub(:make_id).and_return('1', '2', '3', '5', '7', '8', '9')
            connection.should_receive(:post).with(SPEC_URL, batch, {:content_type => 'application/json'}).and_return(@resp_mock)
            @resp_mock.should_receive(:body).at_least(:once).and_return(response)
            client = Client.new(SPEC_URL, :connection => connection)

            sum = subtract = foo = data = nil
            client = BatchClient.new(SPEC_URL, :connection => connection, :named_params => true) do |batch|
              sum = batch.sum(1,2,4)
              subtract = batch.subtract(42,23)
              str = batch.hello('world')
              foo = batch.foo_get('name' => 'myself')
              arr = batch.foo([1,2,3])
              nested = batch.foo({:some => { :nested => :hash }})
              data = batch.get_data
            end

            sum.succeeded?.should be_true
            sum.is_error?.should be_false
            sum.result.should == 7

            subtract.result.should == 19

            foo.is_error?.should be_true
            foo.succeeded?.should be_false
            foo.error['code'].should == -32601

            data.result.should == ['hello', 5]


            expect { client.sum(1, 2) }.to raise_error(NoMethodError)
          end
        end
      end
    end

  end
end
