require 'pubnub/error'
require 'pubnub/uuid'
require 'pubnub/formatter'
require 'pubnub/crypto'
require 'pubnub/constants'
require 'pubnub/configuration'
require 'pubnub/message'
require 'pubnub/subscribe_callback'

require 'pubnub/schemas/envelope_schema'

require 'pubnub/event'
require 'pubnub/single_event'
require 'pubnub/subscribe_event/callbacks'
require 'pubnub/subscribe_event/formatter'
require 'pubnub/subscribe_event/heartbeat'
require 'pubnub/subscribe_event/adding'
require 'pubnub/subscribe_event/removing'
require 'pubnub/subscribe_event'
require 'pubnub/pam'
require 'pubnub/heart'
require 'pubnub/subscriber'

require 'pubnub/envelope'
require 'pubnub/error_envelope'

require 'pubnub/client/events'
require 'pubnub/client/paged_history'
require 'pubnub/client/helpers'

require 'pubnub/validators/common_validator'
require 'pubnub/validators/client'
require 'pubnub/validators/audit'
require 'pubnub/validators/channel_registration'
require 'pubnub/validators/grant'
require 'pubnub/validators/heartbeat'
require 'pubnub/validators/here_now'
require 'pubnub/validators/history'
require 'pubnub/validators/leave'
require 'pubnub/validators/presence'
require 'pubnub/validators/publish'
require 'pubnub/validators/revoke'
require 'pubnub/validators/set_state'
require 'pubnub/validators/state'
require 'pubnub/validators/subscribe'
require 'pubnub/validators/time'
require 'pubnub/validators/where_now'

require 'pubnub/events/audit'
require 'pubnub/events/channel_registration'
require 'pubnub/events/grant'
require 'pubnub/events/heartbeat'
require 'pubnub/events/here_now'
require 'pubnub/events/history'
require 'pubnub/events/leave'
require 'pubnub/events/presence'
require 'pubnub/events/publish'
require 'pubnub/events/revoke'
require 'pubnub/events/set_state'
require 'pubnub/events/state'
require 'pubnub/events/subscribe'
require 'pubnub/events/time'
require 'pubnub/events/where_now'

# Toplevel Pubnub module.
module Pubnub
  # Pubnub client Class.
  class Client
    include Configuration
    include Events
    include PagedHistory
    include Helpers

    attr_reader :env, :subscriber, :heart

    VERSION = Pubnub::VERSION

    # Parameters:
    # ===========
    #
    # <dl>
    #   <dt>subscribe_key</dt>
    #   <dd><b>required.</b> Your subscribe key.</dd>
    #
    #   <dt>publish_key</dt>
    #   <dd><b>optional.</b> Your publish key, without it you can't push messages.</dd>
    #
    #   <dt>secret_key</dt>
    #   <dd><b>optional.</b> Your secret key, required for PAM operations.</dd>
    #
    #   <dt>auth_key</dt>
    #   <dd><b>optional.</b> This client auth key.</dd>
    #
    #   <dt>cipher_key</dt>
    #   <dd><b>optional.</b> Required to encrypt messages.</dd>
    #
    #   <dt>uuid</dt>
    #   <dd><b>optional.</b> Sets given uuid as client uuid, does not generates random uuid on init as usually.</dd>
    #
    #   <dt>origin</dt>
    #   <dd><b>optional.</b> Specifies the fully qualified domain name of the PubNub origin.
    #     By default this value is set to <code>pubsub.pubnub.com</code> but it should be set to the appropriate origin
    #     specified in the PubNub Admin Portal.</dd>
    #
    #   <dt>callback</dt>
    #   <dd><b>optional.</b> Default callback function for all events if not overwrote while firing event.</dd>
    #
    #   <dt>ssl</dt>
    #   <dd><b>optional.</b> Your connection will use ssl if set to true.</dd>
    #
    #   <dt>heartbeat</dt>
    #   <dd><b>optional.</b> Heartbeat interval, if not set heartbeat will not be running.</dd>
    #
    #   <dt>subscribe_timeout</dt>
    #   <dd><b>optional, be careful when modifying this.</b> Timeout for subscribe connection in seconds.</dd>
    #
    #   <dt>non_subscribe_timeout</dt>
    #   <dd><b>optional, be careful when modifying this.</b> Timeout for non-subscribe connection in seconds.</dd>
    #
    #   <dt>max_retries</dt>
    #   <dd><b>optional.</b> How many times client should try to reestablish connection before fail.</dd>
    #
    #   <dt>ttl</dt>
    #   <dd><b>optional.</b> Default ttl for grant and revoke events.</dd>
    # </dl>
    # _examples:_
    # ```ruby
    # # Minimal initialize
    # pubnub = Pubnub.new(subscribe_key: :my_sub_key)
    # ````
    #
    # ```ruby
    # # More complex initialize
    # pubnub = Pubnub.new(
    #   subscribe_key: :demo,
    #   publish_key: :demo,
    #   secret_key: :secret,
    #   cipher_key: :other_secret,
    #   uuid: :mad_max,
    #   origin: 'custom.pubnub.com',
    #   callback: ->(envelope) { puts envelope.message },
    #   connect_callback: ->(message) { puts message },
    #   heartbeat: 60,
    #   subscribe_timeout: 310,
    #   non_subscribe_timeout: 10,
    #   max_retries: 10,
    #   ttl: 0
    # )
    # ```
    # Returns:
    # ========
    #
    # Initialized Pubnub::Client ready to use.
    #
    def initialize(options)
      env_hash = symbolize_options_keys(options)
      setup_app env_hash
      clean_env
      prepare_env
      validate! @env
      Pubnub.logger.debug('Pubnub::Client') do
        "Created new Pubnub::Client instance. Version: #{Pubnub::VERSION}"
      end
    end

    def add_listener(options)
      @subscriber.add_listener(options)
    end

    def remove_listener(options)
      @subscriber.remove_listener(options)
    end

    def subscribed_channels
      @subscriber.channels + @subscriber.wildcard_channels
    end

    def subscribed_groups
      @subscriber.groups
    end

    # Returns:
    # ========
    # True if client is subscribed to at least one channel or channel group, otherwise false.
    def subscribed?
      if @subscriber.nil?
        false
      else
        ![@subscriber.channels, @subscriber.groups, @subscriber.wildcard_channels].flatten.empty?
      end
    end

    # Returns:
    # ========
    # Hash with two keys: :channel and :group, representing currently subscribed channels and groups.
    def subscribed_to(separate_wildcard = false)
      if separate_wildcard
        {
          channel: @subscriber.channels,
          group: @subscriber.groups,
          wildcard_channel: @subscriber.wildcard_channels
        }
      else
        {
          channel: @subscriber.channels + @subscriber.wildcard_channels,
          group: @subscriber.groups
        }
      end
    end

    # Parameters:
    # ===========
    # <dl>
    #   <dt>origin</dt>
    #   <dd>Domain name where connection should be connected.</dd>
    #
    #   <dt>event_type</dt>
    #   <dd>Keyword. :subscribe_event or :single_event.</dd>
    #
    #   <dt>sync</dt>
    #   <dd>Boolean. True if we want dispatcher for sync or sync event, otherwise false.</dd>
    # </dl>
    #
    # Returns:
    # ========
    # Appropriate RequestDispatcher.
    #
    # It returns always new RequestDispatcher for sync events.
    # For async events it checks if there's already RequestDispatcher
    # created and returns it if created, otherwise creates it, assigns
    # it in @env and returns newly created dispatcher.
    def request_dispatcher(origin, event_type, sync)
      Pubnub.logger.debug('Pubnub::Client') do
        "Looking for requester for #{sync ? 'sync' : 'async'} #{event_type}"
      end

      if sync
        @env[:req_dispatchers_pool][:sync][origin] ||= {}
        @env[:req_dispatchers_pool][:sync][origin][event_type] ||=
            setup_httpclient(event_type)
      else
        @env[:req_dispatchers_pool][:async][origin] ||= {}
        @env[:req_dispatchers_pool][:async][origin][event_type] ||=
            setup_httpclient(event_type)
      end
    end

    # Parameters:
    # ===========
    # <dl>
    #   <dt>origin</dt>
    #   <dd>Domain name where connection should be connected.</dd>
    #
    #   <dt>event_type</dt>
    #   <dd>Keyword. :subscribe_event or :single_event.</dd>
    # </dl>
    #
    # Functionality:
    # ==============
    # Terminates request dispatcher for given origin and event type. Usable while restarting subscription.
    def kill_request_dispatcher(origin, event_type)
      Pubnub.logger.debug('Pubnub::Client') { 'Killing requester' }
      # @env[:req_dispatchers_pool][origin][event_type].async.terminate
      @env[:req_dispatchers_pool][:async][origin][event_type].reset_all
      @env[:req_dispatchers_pool][:async][origin][event_type] = nil
    rescue
      Pubnub.logger.debug('Pubnub::Client') { 'There\'s no requester' }
    end

    # Parameters:
    # ===========
    # <dl>
    #   <dt>uuid</dt>
    #   <dd>New uuid to be set.</dd>
    # </dl>
    #
    # Returns:
    # ========
    # New uuid.
    #
    # Functionality:
    # ==============
    # Can't change uuid while subscribed. You have to leave every subscribed channel.
    def change_uuid(uuid)
      Pubnub.logger.debug('Pubnub::Client') { 'Changing uuid' }
      if subscribed?
        fail('Cannot change UUID while subscribed.')
      else
        @env[:uuid] = uuid
      end
    end
    alias_method :session_uuid=, :change_uuid
    alias_method :uuid=, :change_uuid
    alias_method :set_uuid=, :change_uuid

    # Returns:
    # ========
    # Current origin.
    def current_origin
      @env[:origins_pool].first
    end
    alias_method :origin, :current_origin

    # Returns:
    # ========
    # Current client timetoken
    def timetoken
      @env[:timetoken]
    end

    # Retruns:
    # ========
    # Current region or default '0'
    def region_code
      @env[:region_code] || 0
    end

    # Parameters:
    # ===========
    # <dl>
    #   <dt>region</dt>
    #   <dd>New region.</dd>
    # </dl>
    # Returns:
    # ========
    # New region.
    def region_code=(region)
      @env[:region_code] = region
    end

    # Parameters:
    # ===========
    # <dl>
    #   <dt>timetoken</dt>
    #   <dd>New timetoken.</dd>
    # </dl>
    # Returns:
    # ========
    # New timetoken.
    def timetoken=(timetoken)
      @env[:timetoken] = timetoken
    end

    # Returns:
    # ========
    # Current uuid.
    def uuid
      @env[:uuid]
    end

    # Returns:
    # ========
    # Array of all current events.
    # :nocov:
    def events
      @env[:events]
    end
    # :nocov:

    def sequence_number_for_publish!
      @env[:sequence_number_for_publish] += 1
      @env[:sequence_number_for_publish] % 2**32
    end

    def current_heartbeat
      @env[:heartbeat].to_i
    end

    def heartbeat=(value)
      @env[:heartbeat] = value
    end

    def apply_state(event)
      Pubnub.logger.debug('Pubnub::Client') { 'Apply state' }
      create_state_pools(event)

      return unless event.state

      event.channel.each do |channel|
        @env[:state][event.origin][:channel][channel] = event.state
      end

      event.group.each do |group|
        @env[:state][event.origin][:group][group] = event.state
      end
    end

    def empty_state?
      return true unless @env[:state]
      totally_empty @env[:state]
    end

    def generate_ortt
      (::Time.now.to_f * 10_000_000).to_i
    end

    def subscribe_filter=(filter_expr)
      @env[:subscribe_filter] = filter_expr
      @subscriber.reset if subscribed?
      filter_expr
    end

    def subscribe_filter
      @env[:subscribe_filter]
    end

    def sdk_version
      "PubNub-Ruby/#{Pubnub::VERSION}"
    end

    private

    def create_state_pools(event)
      @env[:state] ||= {}
      @env[:state][event.origin] ||= {}
      @env[:state][event.origin][:channel] ||= {}
      @env[:state][event.origin][:group] ||= {}
    end

    def setup_httpclient(event_type)
      if ENV['HTTP_PROXY']
        hc = HTTPClient.new(ENV['HTTP_PROXY'])
      else
        hc = HTTPClient.new
      end

      case event_type
      when :subscribe_event
        hc.receive_timeout = 310
      when :single_event
        hc.receive_timeout = 5
      end

      hc
    end

    def validate!(env)
      Validator::Client.validate! env
    end

    def setup_app(options)
      Pubnub.logger = options[:logger] || Logger.new('pubnub.log')
      Celluloid.logger = Pubnub.logger
      @subscriber = Subscriber.new(self)
      @env = options
    end

    def prepare_env
      assign_defaults
      generate_uuid if @env[:uuid].blank?
      setup_pools
    end

    def generate_uuid
      @env[:uuid] = UUID.generate
    end

    def assign_defaults
      default_values.each do |k, v|
        @env[k] = v unless @env[k]
      end
      @env[:timetoken] = 0
      @env[:sequence_number_for_publish] = 0
    end

    def symbolize_options_keys(options)
      symbolized_options = {}
      options.each_key do |k|
        symbolized_options.merge!(k.to_sym => options[k])
      end
      symbolized_options
    end
  end
end
