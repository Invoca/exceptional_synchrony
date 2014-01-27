require_relative '../test_helper'

describe PNAPI::LimitedFrontEndProxy do
  include ShowHelper
  include TestHelper

  describe "when created" do
    before do
      @front_end_proxy = PNAPI::FrontEndProxy.new
      @limited_front_end_proxy = PNAPI::LimitedFrontEndProxy.new(@front_end_proxy)

      @show_all_response_initial =  {:dnps=>
                                         [    {:id=>1,
                                              :lock_version=>1,
                                              :shard_id=>1,
                                              :api_key=>"aaaaaaaaaaaaaaa",
                                              :parameter_names=>["param1", "param2", "", "", "", "", "", "", "", ""],
                                              :lifetime_seconds=>1000,
                                              :virtual_lines=>
                                                  [{
                                                       :promo_number=>"+18885551111",
                                                       :promo_number_formatted=>"888-555-1111",
                                                       :tracking_url=>"http://overflowtrackingurl.com",
                                                       :line_type=>"PoolOverflow"
                                                       }
                                                  ],
                                              :max_pool_size=>50},
                                             {:id=>2,
                                              :lock_version=>2,
                                              :shard_id=>1,
                                              :api_key=>"bbbbbbbbbbbbbbb",
                                              :parameter_names=>["param1", "param2", "", "", "", "", "", "", "", ""],
                                              :lifetime_seconds=>1000,
                                              :virtual_lines=>
                                                  [{
                                                       :promo_number=>"+18885551112",
                                                       :promo_number_formatted=>"888-555-1111",
                                                       :tracking_url=>"http://overflowtrackingurl.com",
                                                       :line_type=>"PoolOverflow"
                                                       }
                                                  ],
                                              :max_pool_size=>50},
                                             {:id=>3,
                                              :lock_version=>3,
                                              :shard_id=>1,
                                              :api_key=>"ccccccccccccccc",
                                              :parameter_names=>["param1", "param2", "", "", "", "", "", "", "", ""],
                                              :lifetime_seconds=>1000,
                                              :virtual_lines=>
                                                  [{
                                                       :promo_number=>"+18885551113",
                                                       :promo_number_formatted=>"888-555-1111",
                                                       :tracking_url=>"http://overflowtrackingurl.com",
                                                       :line_type=>"PoolOverflow"
                                                       }
                                                  ],
                                              :max_pool_size=>50}
                                         ]
                                  }
    end

    describe "number allocated requests" do
      it "should instantiate a pending number allocated requests object" do
        pending_requests = @limited_front_end_proxy.instance_variable_get(:@pending_number_allocated_requests)
        pending_requests.must_be_kind_of PNAPI::PendingNumberAllocatedRequests
      end

      it "should send max 500 requests on each allocation" do
        ring_pool_id = 1
        promo_number = '+11111111111'
        params       = { param1: "test" }

        assumptions = lambda do |req|
          query = PNAPI::Util.parse_json(req.body)
          assert_equal 500, query[:promo_numbers].count
          true
        end

        stub_request(:post, number_allocated_path).with(&assumptions).to_return(:body => {}.to_json)

        pending_requests = @limited_front_end_proxy.instance_variable_get(:@pending_number_allocated_requests)
        500.times { |i| pending_requests.queue_requests(PNAPI::NumberAllocatedRequest.new(1, "#{i}", "#{i}", Time.now, 0)) }

        PNAPI::EMP.run_and_stop do
          @limited_front_end_proxy.number_allocated(ring_pool_id, promo_number, params)
        end
      end

      it "should requeue any request that fails" do
        stub_request(:post, number_allocated_path).to_timeout

        lambda do
          PNAPI::EMP.run_and_stop do
            @result = @limited_front_end_proxy.number_allocated(1, ['1111111111'], ['test1'])
          end
        end.must_raise PNAPI::StatusError

        pending_requests = @limited_front_end_proxy.instance_variable_get(:@pending_number_allocated_requests)
        pending_requests.pop_requests.count.must_equal 1
      end
    end

    describe "show" do
      it "should pass through when below the limit" do
        PNAPI::EMP.run_and_stop do
          show_body = @show_all_response_initial.to_json
          stub_request(:post, show_all_path).to_return(body: show_body)
          result = @limited_front_end_proxy.show_all
          result.each do |row|
            assert_equal 'PNAPI::DynamicNumberPool', row.class.name, result.inspect
          end
        end
      end
    end

    it "should correctly send and receive json for allocate_number" do
      ring_pool_request = FactoryGirl.build(:ring_pool_request)

      assumptions = lambda do |req|
        (_,  _, api_ver, _, dnp_id, path) = req.uri.path.split("/", 6)
        qparams = PNAPI::Util.parse_query(req.uri.query)
        assert_equal PNAPI::VERSION, api_ver
        assert_equal ring_pool_request.id.to_s, dnp_id
        assert_equal ring_pool_request.key, qparams[:ring_pool_key]
        assert_equal [:param1, :param2, :param3, :ring_pool_key], qparams.keys
      end

      response = {
        promo_number: "+18057771234",
        promo_number_formatted: "805-777-1234",
        tracking_url: "http://trackingurl.com"
      }

      stub_request(:post, allocate_number_pattern).
        with(&assumptions).to_return(:body => response.to_json)

      response = PNAPI::EMP.run_and_stop { @limited_front_end_proxy.allocate_number(ring_pool_request) }

      response.keys.must_equal [:promo_number, :promo_number_formatted, :tracking_url]
    end

    it "should correctly send and receive json for preallocate_numbers" do
      number_count = 10

      response = {
        :allocated_numbers => (1..number_count).map do |i|
          { :number => "+1805405554#{i}" }
        end
      }

      stub_request(:post, preallocate_numbers_path).to_return(:body => response.to_json)

      numbers = PNAPI::EMP.run_and_stop { @limited_front_end_proxy.preallocate_numbers(1, number_count) }

      raw_numbers = numbers[:allocated_numbers].map do |n|
        n[:number]
      end

      raw_numbers.count.must_equal number_count
    end

    it "should correctly send and receive json for number_allocated" do
      ring_pool_id = 10
      promo_number = '8054055544'
      params       = ['bicycles', 'giant']
      presented_at = Time.now

      assumptions = lambda do |req|
        query = PNAPI::Util.parse_json(req.body)
        assert_equal 1, query[:promo_numbers].count

        allocation = query[:promo_numbers].first
        assert_equal ring_pool_id, allocation[:id]
        assert_equal promo_number, allocation[:promo_number]
        assert_equal presented_at.as_json, allocation[:presented_at]
        query.delete(:time_t)
        query.delete(:signature)
        assert_equal params, allocation[:parameter_values]
        true
      end

      stub_request(:post, number_allocated_path).with(&assumptions).to_return(:body => {}.to_json)

      response = PNAPI::EMP.run_and_stop do
        @limited_front_end_proxy.number_allocated(ring_pool_id, promo_number ,params)
      end

      response.must_equal nil
    end
  end

  describe "show" do
    it "should cancel when a duplicate appears" do
      set_test_const('PNAPI::LimitedFrontEndProxy::MAX_FRONT_END_CONCURRENCY', 1)

      @front_end_proxy = PNAPI::FrontEndProxy.new
      @limited_front_end_proxy = PNAPI::LimitedFrontEndProxy.new(@front_end_proxy)

      PNAPI::EMP.run_and_stop do
        show_body = @show_all_response_initial.to_json
        stub_request(:post, show_all_path).to_return(body: { dnps: [] }.to_json )

        responses = PNAPI::Util::ParallelSync.parallel(PNAPI::EMP, @limited_work_queue) do |parallel|
          parallel.add { @limited_front_end_proxy.show_all }
          parallel.add { @limited_front_end_proxy.show_all }
          parallel.add { @limited_front_end_proxy.show_all }
        end

        (0..1).each do |i|
          responses[i].each do |row|
            assert row.is_a?(PNAPI::DynamicNumberPool), responses[i].inspect
          end
        end
        assert_equal :cancelled, responses[2]
      end
    end
  end

  describe "preallocate_numbers" do
    [false, true].each do |same_dnp|
      it "should merge max preallocate if same dnp (#{same_dnp})" do
        set_test_const('PNAPI::LimitedFrontEndProxy::MAX_FRONT_END_CONCURRENCY', 1)

        @front_end_proxy = PNAPI::FrontEndProxy.new
        @limited_front_end_proxy = PNAPI::LimitedFrontEndProxy.new(@front_end_proxy)

        PNAPI::EMP.run_and_stop do
          stub_request(:post, preallocate_numbers_path).to_return do |req|
            count = req.body[/"preallocated_count":(\d+)/,1].to_i
            response = {
                :allocated_numbers => (0...count).map do |i|
                  { :number => "+1805405554#{i}" }
                end
            }
            { body: response.to_json }
          end

          responses = PNAPI::Util::ParallelSync.parallel(PNAPI::EMP, @limited_work_queue) do |parallel|
            parallel.add { @limited_front_end_proxy.preallocate_numbers(1, 1) }
            parallel.add { @limited_front_end_proxy.preallocate_numbers(1, 5) }
            parallel.add { @limited_front_end_proxy.preallocate_numbers(same_dnp ? 1 : 2, 8) }
          end

          expected =
            if same_dnp
              {0 => 1, 1 => 8, 2 => :cancelled}
            else
              {0 => 1, 1 => 5, 2 => 8}
            end
          expected.each do |i, count|
            if count.is_a?(Symbol)
              assert_equal count, responses[i], responses.inspect
            else
              assert responses[i].is_a?(Hash), responses[i].inspect
              responses[i].each do |key, value|
                assert_equal :allocated_numbers, key, key.inspect
                assert value.is_a?(Array), value.inspect
                assert_equal count, value.size, responses[i].inspect
              end
            end
          end
        end
      end
    end
  end
end
