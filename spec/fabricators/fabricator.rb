require 'pathname'

def random_version
  3.times.map {|n| Random.rand(20).to_s }.join('.')
end

def random_mac
  # not strictly a legal MAC, but the shape is correct.  (eg: could be a
  # broadcast MAC, or some other invalid value.)
  6.times.map { Random.rand(256).to_s(16) }.join("-")
end

ASSET_CHARS=('A'..'Z').to_a + ('0'..'9').to_a
def random_asset
  ASSET_CHARS.sample(6).join
end

Fabricator(:broker, :class_name => Razor::Data::Broker) do
  name   { Faker::Commerce.product_name + " #{Fabricate.sequence}" }
  # This is fixed, because we need something on disk to back it!
  broker_type do
    path = Pathname(__FILE__).dirname + '..' + 'fixtures' + 'brokers' + 'test.broker'
    Razor::BrokerType.new(path)
  end
end


Fabricator(:repo, :class_name => Razor::Data::Repo) do
  name      { Faker::Commerce.product_name + " #{Fabricate.sequence}" }
  iso_url   'file:///dev/null'
end


Fabricator(:installer, :class_name => Razor::Data::Installer) do
  name          { Faker::Commerce.product_name + " #{Fabricate.sequence}" }
  os            { Faker::Commerce.product_name }
  os_version    { random_version }
  description   { Faker::Lorem.sentence }
  boot_seq      {{'default' => 'boot_local'}}
end

Fabricator(:policy, :class_name => Razor::Data::Policy) do
  name             { Faker::Commerce.product_name + " #{Fabricate.sequence}" }
  enabled          true
  installer_name   { Fabricate(:installer).name }
  hostname_pattern 'host${id}.example.org'
  root_password    { Faker::Internet.password }
  rule_number      { Fabricate.sequence(:razor_data_policy_rule_number, 100) }

  repo
  broker
end


Fabricator(:node, :class_name => Razor::Data::Node) do
  hw_info { [ "mac=#{random_mac}", "asset=#{random_asset}" ] }
end

Fabricator(:node_with_facts, :class_name => Razor::Data::Node) do
  hw_info { [ "mac=#{random_mac}", "asset=#{random_asset}" ] }
  facts   { { "f1" => "a" } }
end

Fabricator(:bound_node, from: :node) do
  policy

  facts do
    data = {}
    20.times do
      data[Faker::Lorem.word] = case Random.rand(4)
                                when 0 then Faker::Lorem.word
                                when 1 then Random.rand(2**34).to_s
                                when 2 then random_version
                                when 3 then 'true'
                                else raise "unexpected random number!"
                                end
    end
    data
  end

  ip_address { Faker::Internet.ip_v4_address }
  boot_count { Random.rand(10) }

  # normally the node would be created before binding, so we always have an ID
  # assigned; while we are faking one up that doesn't hold, so this helps us
  # skip past the database constraint and the after_save hook fixes everything
  # up before the end user gets their hands on the data.
  hostname   'strictly.temporary.org'

  after_build do |node, _|
    # @todo danielp 2013-08-19: this seems to highlight some data duplication
    # that, frankly, doesn't seem like a good thing to me.
    node.root_password = node.policy.root_password
  end

  after_save do |node, _|
    node.hostname = node.policy.hostname_pattern.gsub('${id}', node.id.to_s)
    node.save
  end
end

Fabricator(:tag, :class_name => Razor::Data::Tag) do
  name { Faker::Commerce.product_name + " #{Fabricate.sequence}" }
  rule { ["=", "1", "1"] }
end
