require "stringio"

module Kafka
  module Protocol

    # A produce request sends a message set to the server.
    #
    # ## API Specification
    #
    #     ProduceRequest => RequiredAcks Timeout [TopicName [Partition MessageSetSize MessageSet]]
    #         RequiredAcks => int16
    #         Timeout => int32
    #         Partition => int32
    #         MessageSetSize => int32
    #
    #     MessageSet => [Offset MessageSize Message]
    #         Offset => int64
    #         MessageSize => int32
    #
    #     Message => Crc MagicByte Attributes Key Value
    #         Crc => int32
    #         MagicByte => int8
    #         Attributes => int8
    #         Key => bytes
    #         Value => bytes
    #
    class ProduceRequest
      attr_reader :transactional_id, :required_acks, :timeout, :messages_for_topics

      # @param required_acks [Integer]
      # @param timeout [Integer]
      # @param messages_for_topics [Hash]
      def initialize(transactional_id: nil, required_acks:, timeout:, messages_for_topics:)
        @transactional_id = transactional_id
        @required_acks = required_acks
        @timeout = timeout
        @messages_for_topics = messages_for_topics
      end

      def api_key
        PRODUCE_API
      end

      def api_version
        3
      end

      def response_class
        requires_acks? ? Protocol::ProduceResponse : nil
      end

      # Whether this request requires any acknowledgements at all. If no acknowledgements
      # are required, the server will not send back a response at all.
      #
      # @return [Boolean] true if acknowledgements are required, false otherwise.
      def requires_acks?
        @required_acks != 0
      end

      def encode(encoder)
        encoder.write_string(@transactional_id)
        encoder.write_int16(@required_acks)
        encoder.write_int32(@timeout)

        encoder.write_array(@messages_for_topics) do |topic, messages_for_partition|
          encoder.write_string(topic)

          encoder.write_array(messages_for_partition) do |partition, record_batch|
            encoder.write_int32(partition)

            record_batch.fulfill_relative_data
            encoded_record_batch = Encoder.encode_with(record_batch)
            encoder.write_bytes(encoded_record_batch)
          end
        end
      end
    end
  end
end
