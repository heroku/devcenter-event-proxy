require 'json'
require 'time'

# Take a string and return a value-hash known to the event manager api
#
# Sample DC event messages and returned value hashes:
#
# ArticleRead:
# {
#   "user_heroku_uid":"351369@users.heroku.com","user_email":"aguy@gmail.com","article_id":650,"article_slug":"quickstart",
#   "article_status":"published","article_title":"Getting Started with Heroku","article_owner_id":58,"article_owner_email":"jon@heroku.com",
#   "at":"2013-01-04T18:59:18+00:00","event_type":"ArticleRead"
# }
# =>
# {
#   :actor_id=>351369, :actor=>"aguy@gmail.com", :target_id=>650, :target=>"quickstart", :owner_id=>58, :owner=>"jon@heroku.com",
#   :timestamp=>1357325958, :action=>"view-article", :attributes=>{:article_status=>"published", :article_title=>"Getting Started with Heroku"}
# }

class DevcenterMessageParser

  EVENT_MSG_REGEX = /"event_type":"(PageVisit|ArticleFeedbackIssueCreated)"/

  DEVCENTER_EVENT_MANAGER_KEY_MAPPINGS = {
    'at' => lambda { |v| { timestamp: Time.parse(v).to_f * 1000 }},
    'event_type' => lambda do |v|
      return { action: 'visit-page' } if v == 'PageVisit'
      return { action: 'submit-feedback' } if v == 'ArticleFeedbackIssueCreated'
    end,
    'user_heroku_uid' => lambda { |v| v.nil? ? {} : { actor_id: v.to_i } },
    'user_email' => lambda { |v| v.nil? ? {} : { actor: v } },
    'page_url' => lambda { |v| { target: v }},
    'url' => lambda { |v| { target: v }},
    'component' => lambda { |v| { component: v }}
  }

  class << self

    # Given a single log message (just the message portion of the raw http logplex string)
    # create an event-manager compatible value hash
    def parse(log_msg)
      if(EVENT_MSG_REGEX.match(log_msg))
        message_values = JSON.parse(log_msg).to_hash
        parsed_values = extract_basic_values(message_values)
        parsed_values.merge!(attributes: extract_attributes_values(message_values))
        parsed_values.merge!(normalize_missing_data(parsed_values))
        parsed_values.merge!(static_values)
        parsed_values[:actor] ? parsed_values : nil
      end
    end

    def extract_basic_values(values)
      values.inject({}) do |result, (key, value)|
        mapper = DEVCENTER_EVENT_MANAGER_KEY_MAPPINGS[key]
        # puts "Extracting #{key}=#{value} to #{mapper.call(value)}" if mapper
        result.merge!(mapper.call(value)) if mapper
        result
      end
    end

    def extract_attributes_values(values)
      case values['event_type']
      when 'PageVisit' then
        { page_title: values['page_title'], page_query_string: values['page_query_string'], referrer_url: values['referrer_url'],
          referrer_query_string: values['referrer_query_string'] }
      when 'ArticleFeedbackIssueCreated' then
        { feedback: values['text'], page_title: values['article_title'] }
      end
    end

    def normalize_missing_data(em_values)
      missing_values = {}
      missing_values[:owner] = em_values[:actor] if !em_values.key?(:owner)
      missing_values[:owner_id] = em_values[:actor_id] if !em_values.key?(:owner_id)
      missing_values[:component] = "devcenter" if !em_values.key?(:component)
      missing_values
    end

    def static_values
      {
        'cloud' => ENV['EVENT_MANAGER_CLOUD'],
        'type' => ENV['EVENT_MANAGER_EVENT_ENTITY_TYPE'],
        'source_ip' => '0.0.0.0',
        'target_id' => -1
      }
    end
  end
end