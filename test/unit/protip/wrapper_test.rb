require 'test_helper'

require 'protip/wrapper'

module Protip::WrapperTest # namespace for internal constants
  describe Protip::Wrapper do
    let(:converter) do
      Class.new do
        include Protip::Converter
      end.new
    end

    class InnerMessage < ::Protobuf::Message
      required :int64, :value, 1
      optional :string, :note, 2
    end
    class Message < ::Protobuf::Message
      optional InnerMessage, :inner, 1
      optional :string, :string, 2
    end

    let(:wrapped_message) do
      Message.new(inner: {value: 25}, string: 'test')
    end

    let(:wrapper) do
      Protip::Wrapper.new(wrapped_message, converter)
    end

    describe '#respond_to?' do
      it 'adds setters for message fields' do
        assert_respond_to wrapper, :string=
        assert_respond_to wrapper, :inner=
      end
      it 'adds getters for message fields' do
        assert_respond_to wrapper, :string
        assert_respond_to wrapper, :inner
      end
      it 'responds to standard defined methods' do
        assert_respond_to wrapper, :as_json
      end
      it 'does not add other setters/getters' do
        refute_respond_to wrapper, :foo=
        refute_respond_to wrapper, :foo
      end
    end

    describe '#build' do
      it 'raises an error when building a primitive field' do
        assert_raises RuntimeError do
          wrapper.build(:string)
        end
      end

      it 'raises an error when building a convertible message' do
        converter.stubs(:convertible?).with(InnerMessage).returns(true)
        assert_raises RuntimeError do
          wrapper.build(:inner)
        end
      end

      describe 'with an inconvertible message field' do
        let(:wrapped_message) { Message.new }

        before do
          converter.stubs(:convertible?).with(InnerMessage).returns(false)
        end

        it 'builds the message when no attributes are provided' do
          assert_nil wrapped_message.inner # Sanity check
          wrapper.build(:inner)
          assert_equal InnerMessage.new, wrapped_message.inner
        end

        it 'overwrites the message if it exists' do
          wrapped_message.inner = InnerMessage.new(value: 4)
          wrapper.build(:inner)
          assert_equal InnerMessage.new, wrapped_message.inner
        end

        it 'delegates to #assign_attributes if attributes are provided' do
          Protip::Wrapper.any_instance.expects(:assign_attributes).once.with({value: 40})
          wrapper.build(:inner, value: 40)
        end

        it 'returns the built message' do
          built = wrapper.build(:inner)
          assert_equal wrapper.inner, built
        end
      end
    end

    describe '#assign_attributes' do
      it 'assigns primitive fields directly' do
        wrapper.assign_attributes string: 'another thing'
        assert_equal 'another thing', wrapped_message.string
      end

      it 'assigns convertible message fields directly' do
        converter.stubs(:convertible?).with(InnerMessage).returns(true)
        converter.expects(:to_message).once.with(45, InnerMessage).returns(InnerMessage.new(value: 43))
        wrapper.assign_attributes inner: 45
        assert_equal InnerMessage.new(value: 43), wrapped_message.inner
      end

      it 'returns nil' do
        assert_nil wrapper.assign_attributes({})
      end

      describe 'when assigning inconvertible message fields' do
        before do
          converter.stubs(:convertible?).with(InnerMessage).returns(false)
        end

        it 'sets multiple attributes' do
          wrapper.assign_attributes string: 'test2', inner: {value: 50}
          assert_equal 'test2', wrapped_message.string
          assert_equal InnerMessage.new(value: 50), wrapped_message.inner
        end

        it 'updates inconvertible message fields which have already been built' do
          wrapped_message.inner = InnerMessage.new(value: 60)
          wrapper.assign_attributes inner: {note: 'updated'}
          assert_equal InnerMessage.new(value: 60, note: 'updated'), wrapped_message.inner
        end

        it 'delegates to itself when setting nested attributes on inconvertible message fields' do
          inner = mock
          wrapper.stubs(:get).with(wrapped_message.class.fields.detect{|f| f.name == :inner}).returns(inner)
          inner.expects(:assign_attributes).once.with(value: 50, note: 'noted')
          wrapper.assign_attributes inner: {value: 50, note: 'noted'}
        end
      end
    end

    describe '#get' do
      it 'does not convert simple fields' do
        converter.expects(:convertible?).never
        converter.expects(:to_object).never
        assert_equal 'test', wrapper.string
      end

      it 'converts convertible messages' do
        converter.expects(:convertible?).with(InnerMessage).once.returns(true)
        converter.expects(:to_object).with(InnerMessage.new(value: 25)).returns 40
        assert_equal 40, wrapper.inner
      end

      it 'wraps inconvertible messages' do
        converter.expects(:convertible?).with(InnerMessage).once.returns(false)
        converter.expects(:to_object).never
        assert_equal Protip::Wrapper.new(InnerMessage.new(value: 25), converter), wrapper.inner
      end
    end

    describe '#set' do
      it 'does not convert simple fields' do
        converter.expects(:convertible?).never
        converter.expects(:to_message).never

        wrapper.string = 'test2'
        assert_equal 'test2', wrapper.message.string
      end

      it 'converts convertible messages' do
        converter.expects(:convertible?).with(InnerMessage).once.returns(true)
        converter.expects(:to_message).with(40, InnerMessage).returns(InnerMessage.new(value: 30))

        wrapper.inner = 40
        assert_equal InnerMessage.new(value: 30), wrapper.message.inner
      end

      it 'raises an error when setting inconvertible messages' do
        converter.expects(:convertible?).with(InnerMessage).once.returns(false)
        converter.expects(:to_message).never
        assert_raises ArgumentError do
          wrapper.inner = 'cannot convert me'
        end
      end

      it 'passes through messages without checking whether they are convertible' do
        converter.expects(:convertible?).never
        converter.expects(:to_message).never

        wrapper.inner = InnerMessage.new(value: 50)
        assert_equal InnerMessage.new(value: 50), wrapper.message.inner
      end
    end
  end
end