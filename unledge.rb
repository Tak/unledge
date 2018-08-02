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

require_relative 'urika'

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

    dump("https://#{url}") { |doc| return send(scraper, doc) }
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

      content = if media_content && !media_content.chomp().empty?
        "Toot: #{text_content} #{media_content}"
      elsif text_content && !text_content.chomp().empty?
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

if (__FILE__ == $0)
  require 'test/unit'

  class UnledgeTest < Test::Unit::TestCase
    def setup()
      @unledge = Unledge.new()
    end # setup

    def test_twitter_detection
      uris = [
        { 'http://twitter.com/foo/bar' => true },
        { 'https://www.twitter.com/foo/bar' => true },
        { 'https://mobile.twitter.com/foo/bar' => true },
        { 'https://t.co/foo/bar' => true },
        { 'https://gitt.co/foo/bar' => false },
        { 'https://allatwitter.com/foo/bar' => false },
        { 'https://nou.twitter.com/foo/bar' => false },
      ]

      uris.each { |pair|
        url = Urika.get_first_url(pair[0])
        matched = Unledge.is_twitter_url(url)
        assert_equal(pair[1], matched, "Unexpected match status #{matched} for input #{pair[0]}")
      }
    end # test_twitter_detection

    def test_mastodon_detection
      uris = [
        { 'http://mastodon.social/@foo/bar' => true },
        { 'https://wat.lgbt.io/@foo/bar' => true },
        { 'https://joe:meh@foo.bar' => false },
        { 'https://gitt.co/foo/@bar' => false },
      ]

      uris.each { |pair|
        url = Urika.get_first_url(pair[0])
        matched = Unledge.is_mastodon_url(url)
        assert_equal(pair[1], matched, "Unexpected match status #{matched} for input #{pair[0]}")
      }
    end # test_mastodon_detection

    def test_scrape
      tests = [
          [ 'test/tweet.html', :scrape_tweet, 'Tweet: feeldog dedass forgot how 내꺼 sounds like for a moment but he did the vocals dance rap wow wat a tru leader pic.twitter.com/e11N2tNUQ0' ],
          [ 'test/toot.html', :scrape_toot, 'Toot: My kids are obsessed with stroopwafels. I guess these things happen.' ],
          [ 'test/tweet_series.html', :scrape_tweet, 'Tweet: Cool looking student project that would probably get you a D in a games class and a cease and desist from Nintendo.' ],
          [ 'test/toot_series.html', :scrape_toot, 'Toot: I have to log off now, for several years.' ],
          [ 'test/tweet_multiline.html', :scrape_tweet, 'Tweet: Scott Baio is now boycotting Dick’s Sporting Goods due to their ban on Simi-automatic weapons   Dick’s Sporting Goods had to call in a replacement cashier to fill in for Scott pic.twitter.com/1AgJonovn7'],
          [ 'test/toot_ellipsized.html', :scrape_toot, 'Toot: Oh.  you would like me to test your application and write bug reports? *cracks knuckles*😈 You bet. https://cybre.space/media/LZMBWEgkic332LmLxCc (Scene from Death note, dramatically writing and eating chips: https://cybre.space/media/LZMBWEgkic332LmLxCc )' ],
          [ 'test/toot_pic.html', :scrape_toot, 'Toot: . ( https://mastodon.technology/media/L_TldXxzfh8IRyfepBE )' ],
          [ 'test/medium_article.html', :scrape_toot, nil ],
      ]

      tests.each { |test|
        assert_equal(test[2], @unledge.dump(test[0]){ |doc| @unledge.send(test[1], doc)})
      }
    end # test_scrape
  end
end
