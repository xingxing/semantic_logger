require_relative '../test_helper'

# Unit Test for SemanticLogger::Appender::Elasticsearch
module Appender
  class ElasticsearchTest < Minitest::Test
    describe SemanticLogger::Appender::Elasticsearch do
      before do
        Elasticsearch::Transport::Client.stub_any_instance(:bulk, true) do
          @appender = SemanticLogger::Appender::Elasticsearch.new(url: 'http://localhost:9200')
        end
        @message = 'AppenderElasticsearchTest log message'
      end

      after do
        @appender.close if @appender
      end

      it 'logs to daily indexes' do
        bulk_index = nil
        @appender.stub(:write_to_elasticsearch, -> messages { bulk_index = messages.first }) do
          @appender.info @message
        end
        index = bulk_index['index']['_index']
        assert_equal "semantic_logger-#{Time.now.strftime('%Y.%m.%d')}", index
      end

      SemanticLogger::LEVELS.each do |level|
        it "send #{level}" do
          request = nil
          @appender.client.stub(:bulk, -> r { request = r; {"status" => 201} }) do
            @appender.send(level, @message)
          end

          message = request[:body][1]
          assert_equal @message, message[:message]
          assert_equal level, message[:level]
        end

        it "sends #{level} exceptions" do
          exc = nil
          begin
            Uh oh
          rescue Exception => e
            exc = e
          end
          request = nil
          @appender.client.stub(:bulk, -> r { request = r; {"status" => 201} }) do
            @appender.send(level, 'Reading File', exc)
          end

          hash = request[:body][1]

          assert_equal 'Reading File', hash[:message]
          assert exception = hash[:exception]
          assert_equal 'NameError', exception[:name]
          assert_match 'undefined local variable or method', exception[:message]
          assert_equal level, hash[:level]
          assert exception[:stack_trace].first.include?(__FILE__), exception
        end

        it "sends #{level} custom attributes" do
          request = nil
          @appender.client.stub(:bulk, -> r { request = r; {"status" => 201} }) do
            @appender.send(level, @message, {key1: 1, key2: 'a'})
          end

          message = request[:body][1]
          assert_equal @message, message[:message]
          assert_equal level, message[:level]
          refute message[:stack_trace]
          assert payload = message[:payload], message
          assert_equal 1, payload[:key1], message
          assert_equal 'a', payload[:key2], message
        end
      end

    end
  end
end
