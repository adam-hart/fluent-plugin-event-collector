require "helper"
require "fluent/plugin/filter_event_collector.rb"

class EventCollectorFilterTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  BASIC_CONF = %[
    event_key request_id
    end_tag_key complete
    end_tag_value true
    event_timeout 1
  ]

  MERGE_CONF = BASIC_CONF + %[
    merge_fields message
    merge_field_delimeter +
  ]

  R1 = [
    {'request_id' => '1', 'message' => 'Hello'},
    {'request_id' => '1', 'message' => 'World!', 'complete' => 'true'}
  ]
  R2 = [
    {'request_id' => '2', 'message' => 'Poop'},
    {'request_id' => '2', 'message' => 'The Cat', 'complete' => 'true'}
  ]

  def create_driver(conf = BASIC_CONF)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::EventCollectorFilter).configure(conf)
  end

  sub_test_case 'filter base functionality' do
    test 'passes through unidentifiable events' do
      d = create_driver
      
      d.run do
        d.feed('filter.test', event_time, {'foo' => 'bar'})
      end

      assert_equal(d.filtered_records.size, 1)
    end
    
    test 'aggregates multiple events with same key value' do
      d = create_driver
      
      d.run do
        d.feed('filter.test', event_time, R1[0])
        d.feed('filter.test', event_time, R1[1])
      end

      assert_equal(d.filtered_records.size, 1)
      assert_equal(R1[1], d.filtered_records.first)
    end

    test 'can aggregate conflated events' do
      d = create_driver
      
      d.run do
        d.feed('filter.test', event_time, R1[0])
        d.feed('filter.test', event_time, R2[0])
        d.feed('filter.test', event_time, R1[1])
        d.feed('filter.test', event_time, R2[1])
      end

      assert_equal(d.filtered_records.size, 2)
      assert_equal(R1[1], d.filtered_records.first)
      assert_equal(R2[1], d.filtered_records.last)
    end

    test 'emits single line events' do
      d = create_driver
      
      d.run do
        d.feed('filter.test', event_time, R1[1])
      end

      assert_equal(d.filtered_records.size, 1)
      assert_equal(R1[1], d.filtered_records.first)
    end

    test 'holds events in buffer if unfinished' do
      d = create_driver
      
      d.run do
        d.feed('filter.test', event_time, R1[0])
      end

      assert_equal(d.filtered_records.size, 0)
    end

    test 'requests time out if not finished' do
      d = create_driver
      
      d.run do
        d.feed('filter.test', event_time, R1[0])
        sleep(3)
      end

      assert_equal(d.emit_count, 1)
    end
  end

  sub_test_case 'filter with merge fields' do
    test 'merges the key fields' do
      d = create_driver(MERGE_CONF)
      
      d.run do
        d.feed('filter.test', event_time, R1[0])
        d.feed('filter.test', event_time, R1[1])
      end

      assert_equal(1, d.filtered_records.size)
      assert_equal('Hello+World!', d.filtered_records.first['message'])
    end
  end
end
