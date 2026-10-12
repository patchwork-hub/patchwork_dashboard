require "test_helper"

class Api::V1::ChannelSerializerTest < ActiveSupport::TestCase
  test "loads favourited counts once for all serialized channels" do
    channels = [Community.new(id: 10), Community.new(id: 20)]
    grouped_scope = Minitest::Mock.new
    relation = Minitest::Mock.new

    where_query = lambda do |conditions|
      assert_equal({ patchwork_community_id: [10, 20] }, conditions)
      relation
    end

    JoinedCommunity.stub(:where, where_query) do
      relation.expect(:group, grouped_scope, [:patchwork_community_id])
      grouped_scope.expect(:count, { 10 => 2 })

      serializer = Api::V1::ChannelSerializer.new(channels)
      counts = serializer.instance_variable_get(:@params)[:favourited_counts]

      assert_equal({ 10 => 2 }, counts)
      relation.verify
      grouped_scope.verify
    end
  end
end