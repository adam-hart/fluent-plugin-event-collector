#
# Copyright 2018- Adam Hart
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "fluent/plugin/filter"

module Fluent
  module Plugin
    class EventCollectorFilter < Fluent::Plugin::Filter
      Fluent::Plugin.register_filter("event_collector", self)

      helpers :timer, :event_emitter

      config_param :event_key, :string

      config_param :end_tag_key, :string
      config_param :end_tag_value, :string

      config_param :merge_fields, :array, value_type: :string, default: []
      config_param :merge_field_delimeter, :string, default: ' '

      config_param :event_timeout, :integer, default: 30

      def configure(conf)
        super

        @event_buffer = {}
        @event_buffer_lock = Mutex.new
      end

      def start
        super

        # Set up event timeout
        timer_execute(:event_timeout, event_timeout, repeat: false, &method(:timeout_flush))
      end

      def filter(tag, time, record)
        # Pass through if we can't associate a record with a event
        return record unless record[event_key]
        
        @event_buffer_lock.synchronize do
          if record[end_tag_key] == end_tag_value
            # Complete event object and publish to rest of fluent chain
            publish_event(record)
          else
            # Merge in fluent's tag and time in case we need to manually emit later
            update_event(record.merge({'fd_tag' => tag, 'fd_time' => time}))

            # nil return halts the fluent event chain for this event
            nil
          end
        end
      end

      private

      # Return a full formed event
      def publish_event(record)
        return record unless event = @event_buffer.delete(record[event_key])

        # Remove any fluent fields we added
        merge_records(event, record).delete_if { |k, _| k =~ /\Afd_/ }
      end

      # Initializes or merges record hashes into a event
      def update_event(record)
        event_id = record[event_key]

        if event = @event_buffer[event_id]
          merge_records(event, record)
        else
          @event_buffer[event_id] = record
        end
      end

      # Merges record hashes where key fields are concatenated
      def merge_records(r1, r2)
        r1.merge!(r2) do |k, v1, v2|
          if merge_fields.include?(k)
          "#{v1}#{merge_field_delimeter}#{v2}"
          else
            v2
          end
        end
      end

      # event timeout callback
      def timeout_flush
        now = Time.now.to_i

        # Snapshot the event buffer and timeout a event if it hasn't been updated in 30s
        timeout_buffer = @event_buffer.dup.each_with_object([]) do |(id, event), buffer|
          buffer << id if (now - event['fd_time'].to_i) > event_timeout
        end

        @event_buffer_lock.synchronize { timeout_events(timeout_buffer) } if timeout_buffer.any?

        # To ensure we don't run more than one timer at a time, enqueue at the end
        timer_execute(:event_timeout, event_timeout, repeat: false, &method(:timeout_flush))
      end

      # Manually emit a fluent event for all timed out events
      def timeout_events(timeout_buffer)
        timeout_buffer.each do |event_id|
          emit_event(@event_buffer.delete(event_id), 'event_timeout')
        end
      end

      def emit_event(event, reason)
        router.emit("#{event.delete('fd_tag')}.#{reason}", event.delete('fd_time'), event)
      end
    end
  end
end
