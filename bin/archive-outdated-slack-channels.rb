#!/usr/bin/env ruby

require 'json'
require 'net/https'
require 'uri'

SLACK_TOKEN = ENV.fetch('SLACK_TOKEN')
SLACK_BOT_USERNAME = ENV.fetch('SLACK_BOT_USERNAME')
SLACK_BOT_ICON_EMOJI = ENV.fetch('SLACK_BOT_ICON_EMOJI')
SLACK_CHANNEL_PATTERN = Regexp.new(ENV.fetch('SLACK_CHANNEL_PATTERN'))
A_MONTH_AGO = 60 * 60 * 24 * 30

def get_channels()
  q = URI.encode_www_form(
    token: SLACK_TOKEN,
    exclude_archived: 'true',
    exclude_members: 'true',
  )
  res = Net::HTTP.get(URI.parse("https://slack.com/api/channels.list?#{q}"))
  JSON.parse(res)['channels']
end

def search_target_channels(channels)
  channels.select {|ch| CHANNEL_PATTERN === ch['name'] }
end

def get_last_message_for(channel)
  q = URI.encode_www_form(
    token: SLACK_TOKEN,
    channel: channel['id'],
    count: 1,
  )
  res = Net::HTTP.get(URI.parse("https://slack.com/api/channels.history?#{q}"))
  body = JSON.parse(res)
  body['messages']
end

def notice_archive(channel)
  res = Net::HTTP.post_form(URI.parse("https://slack.com/api/chat.postMessage"), {
    token: SLACK_TOKEN,
    channel: channel['id'],
    username: SLACK_BOT_USERNAME,
    icon_emoji: SLACK_BOT_ICON_EMOJI,
    text: '1ヶ月以上発言がないのでarchiveします。いままでご愛顧ありがとうございました。まだ使っている場合はunarchiveすることもできます。',
    as_user: false,
  })
  pp res.body
  Net::HTTPSuccess === res
end

def archive_channel(channel)
  res = Net::HTTP.post_form(URI.parse("https://slack.com/api/channels.archive"), {
    token: SLACK_TOKEN,
    channel: channel['id'],
  })
  pp res.body
  Net::HTTPSuccess === res
end

now = Time.now
channels = get_channels()
target_channels = search_target_channels(channels)
puts "#{target_channels.size} channels found"
target_channels.each do |ch|
  last_msg = get_last_message_for(ch).first
  last_msg_at = Time.at(last_msg['ts'].to_f)
  too_old = (now - last_msg_at) > A_MONTH_AGO
  next unless too_old
  puts "##{ch['name']} (last: #{last_msg_at})"
  archive_channel(ch) if notice_archive(ch)
  sleep 1
end
