#!/usr/bin/env ruby
# encoding: utf-8

# This program is free software; you can redistribute it and/or modify it under the terms of the GNU
# General Public License as published by the Free Software Foundation; either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.

require 'nokogiri'
require 'open-uri'
require 'json'

require 'urika'

module Unledge
  class Unledge
    TWITTER_HOSTS = [
      /^((www|mobile).)?twitter.com\//,
      /^t.co\//,
    ].freeze

    MASTODON_PATTERN = /[^\/]+\/@[^\/]+\//
    TWITTER_PIC_LINK_PATTERN = /([^\s\/])(pic.twitter.com)/

    # Processes a statement
    # param text The text of the statement
    def process_statement(text)
      return nil unless (url = Urika.get_first_url(text))
      scraper = if (Unledge.is_twitter_url(url))
                  :scrape_tweet
                elsif (Unledge.is_mastodon_url(url))
                  :scrape_toot
                end
      return nil unless scraper

      dump("https://#{Unledge.normalize_url(url)}") { |doc| return send(scraper, doc) }
    end

    def self.normalize_url(url)
      return url unless (Unledge.is_twitter_url(url))
      return url.sub(/^mobile\./, '')
    end

    def self.is_twitter_url(url)
      return TWITTER_HOSTS.detect { |host|
        host.match(url)
      }
    end

    def self.is_mastodon_url(url)
      return MASTODON_PATTERN.match(url)
    end

    def strip_tags(text)
      text.gsub!(/(<[^>]*>|\r|\n)/, ' ')
      return text.gsub(TWITTER_PIC_LINK_PATTERN, '\1 \2')
    end

    def scrape_toot(doc)
      content = nil
      begin
        # TODO: CW text
        toot = doc.css('div[class="entry entry-center"]')
        text_content = toot.css('div[class="e-content"]').inner_text
        media_gallery = toot.css('div[data-component="MediaGallery"]')
        unless media_gallery.empty?
          begin
            media = JSON.parse(media_gallery[0].attributes['data-props'].value)
            media_content = if media['media'][0]['description']
                              "(#{media['media'][0]['description']}: #{media['media'][0]['text_url']} )"
                            else
                              "( #{media['media'][0]['text_url']} )"
                            end
          rescue => error
            puts "Error scraping media from toot: #{error}\n#{media}"
          end
        end

        text_content.strip! if text_content
        media_content.strip! if media_content

        content = if media_content && !media_content.empty?
          "Toot: #{text_content} #{media_content}"
        elsif text_content && !text_content.empty?
          "Toot: #{text_content}"
        else
          nil
        end
      rescue => error
        puts "Error scraping content from toot: #{error}"
      end

      return content
    end

    def scrape_tweet(doc)
      begin
        # FIXME: This class might be fragile
        return strip_tags("Tweet: #{doc.css('p[class="TweetTextSize TweetTextSize--jumbo js-tweet-text tweet-text"]')[0].inner_text}")
      rescue => error
        puts "Error scraping content from tweet: #{error}"
      end

      return nil
    end

    def dump(url)
      begin
        yield Nokogiri::HTML(open(url))
      rescue => error
        puts "Couldn't load #{url}: #{error}"
      end
    end
  end
end

if (__FILE__ == $0)
  require 'test/unit'

  class UnledgeTest < Test::Unit::TestCase
  end
end
