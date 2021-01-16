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
require 'cgi'

require 'urika'

module Unledge
  class Unledge
    TWITTER_HOSTS = [
      /^((www|mobile).)?twitter.com\//,
      /^t.co\//,
    ].freeze

    MASTODON_PATTERN = /[^\/]+\/@[^\/]+\//
    PLEROMA_PATTERN = /[^\/]+\/(objects|notice)\/[-\w]+/
    TWITTER_PIC_LINK_PATTERN = /([^\s\/])(pic.twitter.com)/
    TWITTER_INVISIBLE_SPAN_PATTERN = /<span[^>]*>([^<]*)<\/span>/

    # Processes a statement
    # param text The text of the statement
    def process_statement(text)
      return nil unless (url = Urika.get_first_url(text))
      is_twitter = Unledge.is_twitter_url(url)
      scraper = if (is_twitter)
                  :scrape_tweet_embed
                elsif (Unledge.is_mastodon_url(url))
                  :scrape_toot
                elsif (Unledge.is_pleroma_url(url))
                  :scrape_pleroma
                end
      return nil unless scraper

      if (is_twitter)
        dump_embed("https://#{Unledge.normalize_url(url)}") { |doc| return send(scraper, doc) }
      else
        dump("https://#{Unledge.normalize_url(url)}") { |doc| return send(scraper, doc) }
      end
    end

    def self.normalize_url(url)
      return url unless (Unledge.is_twitter_url(url))
      return "publish.twitter.com/oembed?url=https://#{url}"
    end

    def self.is_twitter_url(url)
      return TWITTER_HOSTS.detect { |host|
        host.match(url)
      }
    end

    def self.is_mastodon_url(url)
      return MASTODON_PATTERN.match(url)
    end

    def self.is_pleroma_url(url)
      return PLEROMA_PATTERN.match(url)
    end

    def strip_tags(text)
      text.gsub!(TWITTER_INVISIBLE_SPAN_PATTERN, '\1')
      text.gsub!(/(<[^>]*>|\r|\n)/, ' ')
      return text.gsub(TWITTER_PIC_LINK_PATTERN, '\1 \2')
    end

    def scrape_pleroma(doc)
      content = nil
      url = nil
      begin
        post = doc.css('meta[property="twitter:description"]')[0]
        content = post['content']
        begin
          # Try to scrape media
          # TODO: description?
          media = doc.css('meta[property="twitter:player"]')[0]
          url = media['content']
        rescue
          # Unable to scrape media
        end
      rescue => error
        puts "Error scraping toot: #{error}"
      end

      if content
        if url
          "Toot: #{content.strip} ( #{url.strip} )"
        else
          "Toot: #{content.strip}"
        end
      else
        nil
      end
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
                              "(#{media['media'][0]['description'].gsub(/\n/, ' ')}: #{media['media'][0]['text_url']} )"
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
        element = doc.css('table.main-tweet tr td.tweet-content div.tweet-text')[0] ||
          doc.css('p[class="TweetTextSize TweetTextSize--jumbo js-tweet-text tweet-text"]')[0]
        return "Tweet: #{strip_tags(element.inner_html).strip()}"
      rescue => error
        puts "Error scraping content from tweet: #{error}"
      end

      return nil
    end

    def scrape_tweet_embed(doc)
      begin
        return "Tweet: #{strip_tags(doc.inner_html).strip()}"
      rescue => error
        puts "Error scraping content from tweet: #{error}"
        # puts error.backtrace.join("\n")
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

    def dump_embed(url)
      begin
        yield Nokogiri::HTML.fragment(CGI.unescape(JSON.load(open(url))['html']))
      rescue => error
        puts "Couldn't load #{url}: #{error}"
        # puts error.backtrace.join("\n")
      end
    end
  end
end
